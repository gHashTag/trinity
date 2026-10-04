package telegram

import (
	"context"
	"fmt"
	"time"

	"github.com/gotd/td/tg"
)

// SentCode describes how Telegram actually delivered a login code.
//
// The UI used to guess between "app" and "SMS". It has no business guessing:
// auth.sendCode says which channel it used, how long the code is, how long the
// caller must wait before asking for another, and what the next channel would
// be. All four are reported here so the screen can state a fact instead of a
// hopeful default.
type SentCode struct {
	CodeHash string `json:"code_hash"`
	// Type is the channel the code went to: app, sms, call, missed_call,
	// flash_call, email, fragment, firebase_sms, or setup_email_required.
	Type string `json:"type"`
	// Length is the number of digits, where the channel defines one.
	Length int `json:"length,omitempty"`
	// TimeoutSeconds is Telegram's own timeout before a resend is allowed.
	// Zero means Telegram sent none, and the caller must not invent one.
	TimeoutSeconds int `json:"timeout_seconds,omitempty"`
	// NextType is the channel a resend would use, empty if Telegram did not
	// offer one -- in which case there is nothing to resend to.
	NextType string `json:"next_type,omitempty"`
	// Detail carries channel-specific information the user needs: the
	// Fragment URL, the flash-call pattern, the missed-call prefix, the
	// email pattern.
	Detail string `json:"detail,omitempty"`
	// AlreadyAuthorized is set when Telegram short-circuited the flow.
	AlreadyAuthorized bool `json:"already_authorized,omitempty"`
}

// CanResend reports whether Telegram offered a next delivery channel.
func (s SentCode) CanResend() bool { return s.NextType != "" }

// describeSentCodeType maps a tg.AuthSentCodeTypeClass onto the wire names and
// the human-visible detail. Every branch is named; an unknown type is reported
// as unknown rather than silently rendered as "app".
func describeSentCodeType(t tg.AuthSentCodeTypeClass) (kind string, length int, detail string) {
	switch v := t.(type) {
	case *tg.AuthSentCodeTypeApp:
		return "app", v.Length, "sent to another logged-in Telegram session on this number"
	case *tg.AuthSentCodeTypeSMS:
		return "sms", v.Length, ""
	case *tg.AuthSentCodeTypeCall:
		return "call", v.Length, "dictated by an automated call"
	case *tg.AuthSentCodeTypeFlashCall:
		return "flash_call", 0, v.Pattern
	case *tg.AuthSentCodeTypeMissedCall:
		return "missed_call", v.Length, "last digits of the calling number, prefix " + v.Prefix
	case *tg.AuthSentCodeTypeEmailCode:
		return "email", v.Length, v.EmailPattern
	case *tg.AuthSentCodeTypeSetUpEmailRequired:
		return "setup_email_required", 0, "the account must set up a login email before a code can be sent"
	case *tg.AuthSentCodeTypeFragmentSMS:
		return "fragment", v.Length, v.URL
	case *tg.AuthSentCodeTypeFirebaseSMS:
		return "firebase_sms", v.Length, ""
	default:
		return "unknown", 0, fmt.Sprintf("%T", t)
	}
}

// describeNextType maps the optional next-delivery hint.
func describeNextType(t tg.AuthCodeTypeClass) string {
	switch t.(type) {
	case *tg.AuthCodeTypeSMS:
		return "sms"
	case *tg.AuthCodeTypeCall:
		return "call"
	case *tg.AuthCodeTypeFlashCall:
		return "flash_call"
	case *tg.AuthCodeTypeMissedCall:
		return "missed_call"
	case *tg.AuthCodeTypeFragmentSMS:
		return "fragment"
	default:
		return ""
	}
}

// readSentCode turns the raw auth.sentCode into a SentCode and records the
// parts of it the resend path needs.
func (c *Client) readSentCode(sentCode tg.AuthSentCodeClass) SentCode {
	switch v := sentCode.(type) {
	case *tg.AuthSentCode:
		kind, length, detail := describeSentCodeType(v.Type)

		next := ""
		if nt, ok := v.GetNextType(); ok {
			next = describeNextType(nt)
		}
		timeout, _ := v.GetTimeout()

		c.mu.Lock()
		c.authFlow.codeHash = v.PhoneCodeHash
		c.authFlow.codeType = kind
		c.authFlow.nextType = next
		c.authFlow.timeout = timeout
		c.authFlow.sentAt = time.Now()
		c.mu.Unlock()

		return SentCode{
			CodeHash:       v.PhoneCodeHash,
			Type:           kind,
			Length:         length,
			TimeoutSeconds: timeout,
			NextType:       next,
			Detail:         detail,
		}

	case *tg.AuthSentCodeSuccess:
		c.mu.Lock()
		c.isAuthed = true
		c.mu.Unlock()
		return SentCode{AlreadyAuthorized: true}
	}

	return SentCode{Type: "unknown"}
}

// ResendCode asks Telegram to deliver the code over its next channel.
//
// This is not the same call as repeating SendCode. auth.sendCode starts the
// flow again and Telegram is free to pick the same channel it already used, so
// a "request a new code" button wired to it changes nothing for a user who has
// no other session to receive an app code. auth.resendCode advances to the
// next_type Telegram itself nominated, which is the only way the channel
// actually changes.
func (c *Client) ResendCode(ctx context.Context) (SentCode, error) {
	c.mu.RLock()
	phone := c.authFlow.phone
	codeHash := c.authFlow.codeHash
	next := c.authFlow.nextType
	timeout := c.authFlow.timeout
	sentAt := c.authFlow.sentAt
	c.mu.RUnlock()

	if phone == "" || codeHash == "" {
		return SentCode{}, fmt.Errorf("send code first")
	}
	if next == "" {
		return SentCode{}, fmt.Errorf("telegram offered no next delivery channel for this number; a resend would change nothing -- use QR login instead")
	}
	if timeout > 0 {
		if wait := time.Duration(timeout)*time.Second - time.Since(sentAt); wait > 0 {
			return SentCode{}, fmt.Errorf("resend not permitted for another %d seconds", int(wait.Seconds())+1)
		}
	}

	sentCode, err := c.api.API().AuthResendCode(ctx, &tg.AuthResendCodeRequest{
		PhoneNumber:   phone,
		PhoneCodeHash: codeHash,
	})
	if err != nil {
		return SentCode{}, fmt.Errorf("resend code: %w", err)
	}

	return c.readSentCode(sentCode), nil
}

// PendingAuth is the part of an unfinished login that must outlive the
// process. Keeping it only in memory meant a redeploy between "enter phone"
// and "enter code" silently lost the flow and the user's code stopped working
// with no explanation.
type PendingAuth struct {
	Phone     string    `json:"phone"`
	CodeHash  string    `json:"code_hash"`
	CodeType  string    `json:"code_type"`
	NextType  string    `json:"next_type"`
	Timeout   int       `json:"timeout"`
	SentAt    time.Time `json:"sent_at"`
	QRToken   string    `json:"qr_token,omitempty"`
	QRExpires time.Time `json:"qr_expires,omitempty"`
}

// ExportPendingAuth snapshots the unfinished login for persistence.
func (c *Client) ExportPendingAuth() PendingAuth {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return PendingAuth{
		Phone:     c.authFlow.phone,
		CodeHash:  c.authFlow.codeHash,
		CodeType:  c.authFlow.codeType,
		NextType:  c.authFlow.nextType,
		Timeout:   c.authFlow.timeout,
		SentAt:    c.authFlow.sentAt,
		QRToken:   c.authFlow.qrToken,
		QRExpires: c.authFlow.qrExpires,
	}
}

// RestorePendingAuth reinstates an unfinished login after a restart.
func (c *Client) RestorePendingAuth(p PendingAuth) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.authFlow.phone = p.Phone
	c.authFlow.codeHash = p.CodeHash
	c.authFlow.codeType = p.CodeType
	c.authFlow.nextType = p.NextType
	c.authFlow.timeout = p.Timeout
	c.authFlow.sentAt = p.SentAt
	c.authFlow.qrToken = p.QRToken
	c.authFlow.qrExpires = p.QRExpires
}
