package telegram

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/gotd/td/telegram/auth/qrlogin"
	"github.com/gotd/td/tg"
	"github.com/gotd/td/tgerr"
)

// QR login is the second route into an account, and for some users it is the
// only one.
//
// sentCodeTypeApp delivers the login code to other logged-in sessions of the
// same number. A user whose only session is the one they are trying to create
// has nowhere to receive it, and no amount of resending changes that: the code
// is not lost, it was delivered to a set of zero devices. auth.exportLoginToken
// does not depend on code delivery at all -- the already-logged-in phone scans
// a token and confirms. That is why this path exists.

// QRCode is the token a client turns into a scannable image.
type QRCode struct {
	// URL is the tg://login?token=... link. Render it as a QR code; the
	// Telegram app's "Link Desktop Device" scanner reads it.
	URL string `json:"url"`
	// ExpiresAt is when Telegram stops accepting this token. Past it, call
	// ExportQR again -- the login itself is not lost, only the token.
	ExpiresAt time.Time `json:"expires_at"`
}

// QRState is the outcome of one poll of the QR login.
type QRState string

const (
	// QRPending means the token has not been scanned yet.
	QRPending QRState = "pending"
	// QRExpired means the token timed out; export a fresh one.
	QRExpired QRState = "expired"
	// QRNeedsPassword means the token was accepted and the account has 2FA.
	// The cloud password must now be supplied via Check2FA -- exactly the
	// same second factor as the code path.
	QRNeedsPassword QRState = "needs_password"
	// QRAuthorized means the login is complete.
	QRAuthorized QRState = "authorized"
)

// QRStatus is a poll result.
type QRStatus struct {
	State QRState `json:"state"`
	// Token is set when a fresh token was issued during this poll, either
	// because the previous one expired or because Telegram rotated it.
	Token *QRCode `json:"token,omitempty"`
	User  *User   `json:"user,omitempty"`
}

// qr builds the login helper, with DC migration wired to the client's own
// connection so a token issued on the wrong DC does not dead-end.
func (c *Client) qr() qrlogin.QR {
	return qrlogin.NewQR(c.api.API(), c.appID, c.appHash, qrlogin.Options{
		Migrate: c.api.MigrateTo,
	})
}

// ExportQR issues a login token and records it against the pending flow.
func (c *Client) ExportQR(ctx context.Context) (*QRCode, error) {
	token, err := c.qr().Export(ctx)
	if err != nil {
		return nil, fmt.Errorf("export login token: %w", err)
	}
	if token.Empty() {
		// AuthLoginTokenSuccess: a previous token was already accepted.
		c.mu.Lock()
		c.isAuthed = true
		c.mu.Unlock()
		return nil, nil
	}

	code := &QRCode{URL: token.URL(), ExpiresAt: token.Expires()}

	c.mu.Lock()
	c.authFlow.qrToken = token.String()
	c.authFlow.qrExpires = token.Expires()
	c.mu.Unlock()

	return code, nil
}

// PollQR asks Telegram whether the token has been scanned.
//
// One call, one honest answer: still waiting, expired and here is a new one,
// scanned but the account wants its cloud password, or done. The caller polls
// this rather than holding a socket open, so a redeploy between the scan and
// the confirmation does not lose the flow -- the token lives in the persisted
// pending-auth record, not in a goroutine.
func (c *Client) PollQR(ctx context.Context) (*QRStatus, error) {
	auth, err := c.qr().Import(ctx)
	if err == nil {
		user, uerr := c.acceptAuthorization(auth)
		if uerr != nil {
			return nil, uerr
		}
		return &QRStatus{State: QRAuthorized, User: user}, nil
	}

	// The account has 2FA. The token was accepted; only the second factor
	// is outstanding, and it is the same Check2FA the code path uses.
	if tgerr.Is(err, "SESSION_PASSWORD_NEEDED") {
		return &QRStatus{State: QRNeedsPassword}, nil
	}

	// Import re-exports the token to learn its state. An unscanned token
	// comes back as auth.loginToken, which Import cannot use and reports as
	// an unexpected type -- that is "not scanned yet", not a failure.
	if isUnscannedToken(err) {
		c.mu.RLock()
		expires := c.authFlow.qrExpires
		c.mu.RUnlock()
		if !expires.IsZero() && time.Now().After(expires) {
			fresh, ferr := c.ExportQR(ctx)
			if ferr != nil {
				return nil, ferr
			}
			return &QRStatus{State: QRExpired, Token: fresh}, nil
		}
		return &QRStatus{State: QRPending}, nil
	}

	if tgerr.Is(err, "AUTH_TOKEN_EXPIRED") {
		fresh, ferr := c.ExportQR(ctx)
		if ferr != nil {
			return nil, ferr
		}
		return &QRStatus{State: QRExpired, Token: fresh}, nil
	}

	return nil, fmt.Errorf("poll qr login: %w", err)
}

// isUnscannedToken reports whether the error is Import's complaint about being
// handed a still-pending auth.loginToken.
func isUnscannedToken(err error) bool {
	return err != nil && strings.Contains(err.Error(), "unexpected type *tg.AuthLoginToken")
}

// acceptAuthorization records a completed login and returns the user.
func (c *Client) acceptAuthorization(auth *tg.AuthAuthorization) (*User, error) {
	user, ok := auth.User.(*tg.User)
	if !ok {
		return nil, fmt.Errorf("unexpected user type %T", auth.User)
	}

	c.mu.Lock()
	c.isAuthed = true
	c.mu.Unlock()

	if err := c.SaveSession(); err != nil {
		return nil, fmt.Errorf("save session after qr login: %w", err)
	}

	return &User{
		ID:        user.ID,
		FirstName: user.FirstName,
		LastName:  user.LastName,
		Username:  user.Username,
		Phone:     user.Phone,
	}, nil
}
