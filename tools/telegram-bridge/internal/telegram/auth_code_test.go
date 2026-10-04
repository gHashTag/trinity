package telegram

import (
	"testing"

	"github.com/gotd/td/tg"
)

// The defect these guard: the bridge told every user "app/SMS" regardless of
// what Telegram said, so a user whose code went to a set of zero logged-in
// sessions was advised to wait for an SMS that could never arrive.
func TestDescribeSentCodeType(t *testing.T) {
	cases := []struct {
		name     string
		in       tg.AuthSentCodeTypeClass
		wantKind string
		wantLen  int
	}{
		{"app", &tg.AuthSentCodeTypeApp{Length: 5}, "app", 5},
		{"sms", &tg.AuthSentCodeTypeSMS{Length: 5}, "sms", 5},
		{"call", &tg.AuthSentCodeTypeCall{Length: 6}, "call", 6},
		{"missed", &tg.AuthSentCodeTypeMissedCall{Prefix: "+79", Length: 4}, "missed_call", 4},
		{"email", &tg.AuthSentCodeTypeEmailCode{EmailPattern: "d*@e*.com", Length: 6}, "email", 6},
		{"fragment", &tg.AuthSentCodeTypeFragmentSMS{URL: "https://fragment.com/x", Length: 6}, "fragment", 6},
		{"firebase", &tg.AuthSentCodeTypeFirebaseSMS{Length: 6}, "firebase_sms", 6},
		{"setup_email", &tg.AuthSentCodeTypeSetUpEmailRequired{}, "setup_email_required", 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			kind, length, _ := describeSentCodeType(c.in)
			if kind != c.wantKind {
				t.Errorf("kind = %q, want %q", kind, c.wantKind)
			}
			if length != c.wantLen {
				t.Errorf("length = %d, want %d", length, c.wantLen)
			}
		})
	}
}

// An unrecognised type must say so rather than fall back to "app". Reporting
// an unknown channel as the one channel that silently delivers nowhere is the
// exact failure being fixed.
func TestDescribeSentCodeTypeUnknownIsNotApp(t *testing.T) {
	kind, _, detail := describeSentCodeType(&tg.AuthSentCodeTypeSMSWord{})
	if kind != "unknown" {
		t.Fatalf("kind = %q, want %q", kind, "unknown")
	}
	if detail == "" {
		t.Error("unknown type reported no detail; the caller has nothing to show")
	}
}

func TestDescribeNextType(t *testing.T) {
	if got := describeNextType(&tg.AuthCodeTypeSMS{}); got != "sms" {
		t.Errorf("sms next type = %q", got)
	}
	if got := describeNextType(&tg.AuthCodeTypeCall{}); got != "call" {
		t.Errorf("call next type = %q", got)
	}
}

// CanResend is what the UI uses to decide whether to offer the button at all.
// Offering it when Telegram nominated no next channel is how the old flow
// promised the user something it could not deliver.
func TestCanResend(t *testing.T) {
	if (SentCode{NextType: "sms"}).CanResend() != true {
		t.Error("a nominated next channel should be resendable")
	}
	if (SentCode{}).CanResend() != false {
		t.Error("no next channel means no resend; the button must not be offered")
	}
}

// A resend with no next channel must fail loudly instead of repeating
// auth.sendCode and appearing to work.
func TestResendCodeRefusesWithoutNextChannel(t *testing.T) {
	c := &Client{authFlow: &authFlow{}}
	c.authFlow.phone = "+79990000000"
	c.authFlow.codeHash = "hash"
	// nextType deliberately empty.

	if _, err := c.ResendCode(t.Context()); err == nil {
		t.Fatal("expected refusal when Telegram nominated no next channel")
	}
}

func TestResendCodeRequiresSendCodeFirst(t *testing.T) {
	c := &Client{authFlow: &authFlow{}}
	if _, err := c.ResendCode(t.Context()); err == nil {
		t.Fatal("expected refusal when no code has been sent")
	}
}

func TestPendingAuthRoundTrip(t *testing.T) {
	c := &Client{authFlow: &authFlow{}}
	in := PendingAuth{
		Phone:    "+79990000000",
		CodeHash: "hash",
		CodeType: "app",
		NextType: "sms",
		Timeout:  60,
		QRToken:  "tok",
	}
	c.RestorePendingAuth(in)
	out := c.ExportPendingAuth()

	if out.Phone != in.Phone || out.CodeHash != in.CodeHash ||
		out.CodeType != in.CodeType || out.NextType != in.NextType ||
		out.Timeout != in.Timeout || out.QRToken != in.QRToken {
		t.Errorf("round trip lost data: got %+v, want %+v", out, in)
	}
}
