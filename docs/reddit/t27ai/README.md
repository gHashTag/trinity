# r/t27ai Subreddit Setup

Complete content package for setting up the r/t27ai subreddit for the Trinity project.

## Files

| File | Purpose |
|------|---------|
| `SIDEBAR.md` | Sidebar content (description, features, links, install) |
| `RULES.md` | Community rules (7 rules) |
| `WELCOME_POST.md` | Welcome post for new community members |
| `EXAMPLE_POSTS.md` | 10 example posts across all categories |

## Quick Setup

### 1. Create Subreddit

Go to: https://www.reddit.com/subreddits/create

- **Name**: `t27ai`
- **Title**: `Trinity — Pure Zig Ternary Computing`
- **Description**: (see SIDEBAR.md)
- **Type**: Public
- **Over 18**: No
- **Wiki**: Enabled

### 2. Configure Sidebar

1. Go to: https://www.reddit.com/r/t27ai/about/sidebar
2. Copy content from `SIDEBAR.md`
3. Paste into sidebar editor

### 3. Configure Flairs

Go to: https://www.reddit.com/r/t27ai/about/flairs

Create 8 flairs:

| Flair | Color | Text |
|-------|-------|------|
| Question | Blue | 📝 `[Question]` |
| Discussion | Green | 💬 `[Discussion]` |
| Code | Orange | 💻 `[Code]` |
| Research | Purple | 🔬 `[Research]` |
| News | Red | 📢 `[News]` |
| Bug | Dark Red | 🐛 `[Bug]` |
| Feature | Yellow | ✨ `[Feature]` |
| Results | Cyan | 📊 `[Results]` |

### 4. Post Welcome Message

1. Go to: https://www.reddit.com/r/t27ai/submit
2. Title: `Welcome to r/t27ai! 👋`
3. Content: Copy from `WELCOME_POST.md`
4. Flair: `[News]`
5. **Distinguish** (mod post)
6. **Sticky** (pin to top)

### 5. Configure Rules

Go to: https://www.reddit.com/r/t27ai/about/rules

Add 7 rules from `RULES.md`:

1. Be Respectful
2. Search Before Posting
3. Use Flair Tags
4. Technical Questions (include MRE)
5. Language (English & Russian welcome)
6. Bug Reports (use GitHub Issues)
7. Self-Promotion (moderation)

### 6. Set Up Wiki

Go to: https://www.reddit.com/r/t27ai/wiki/

Create wiki pages:

- `index` — Overview and quick links
- `installation` — Installation guide
- `vsa` — VSA operations explained
- `tri-27` — TRI-27 VM guide
- `fpga` — FPGA synthesis guide
- `research` — Scientific publications

### 7. Add Moderators

Go to: https://www.reddit.com/r/t27ai/about/moderators

Add:
- u/gHashTag (owner)
- u/playra
- [other contributors]

### 8. Configure Auto-Moderator

Create config at: https://www.reddit.com/r/t27ai/wiki/config/automoderator

```yaml
# Auto-approve verified users
author:
    gHashTag:
        approve: true
    playra:
        approve: true

# Require flair for all posts
title: ["*"]
require_flair: true

# Filter spam
spam_keywords:
    - "crypto"
    - "buy now"
    - "click here"
    - "free money"
action: remove
```

### 9. Pin Important Posts

Create and pin:

1. **Welcome post** (already done)
2. **Installation guide** — link to docs
3. **Quick start guide** — basic commands
4. **Community rules** — summary of rules

### 10. Enable Post Types

Go to: https://www.reddit.com/r/t27ai/about/edit

Enable:
- ✅ Posts
- ✅ Comments
- ✅ Wiki
- ✅ Images
- ✅ Videos
- ✅ Links

### 11. Set Up External Links

Sidebar links section:

```
[Official Links]
Documentation: https://t27.ai/docs/
GitHub: https://github.com/gHashTag/trinity
Zenodo: https://zenodo.org/communities/trinity
Twitter: https://twitter.com/trinity_cli
Discord: [your Discord invite]
Telegram: [your Telegram link]
```

### 12. Add to Multireddit

Add to relevant multireddits:
- r/zig
- r/FPGA
- r/MachineLearning
- r/artificial
- r/compsci

---

## Content Themes

### Technical Discussion
- Ternary computing: {-1, 0, +1} vs float32
- VSA operations: bind, unbind, bundle
- TRI-27: ternary core (27 registers, 36 opcodes)
- FPGA: LLM on QMTech XC7A100T ($30)
- Zig development: pure code, zero deps

### Mathematical Research
- Trinity Identity: φ² + 1/φ² = 3
- Connection to constants: G, α, N_gen = 3
- Sacred mathematics: 75+ constants
- DARPA CLARA: polynomial-time guarantees

### AI/ML Research
- BitNet LLM: CPU inference without GPU
- HSLM: 1.95M params, 385 KB
- DePIN network: distributed inference
- Autonomous agents: ralph-agent, tri-api, tri-bot

### News & Updates
- Releases: GitHub releases
- Publications: Zenodo community
- Documentation: https://t27.ai/docs/

---

## Ongoing Maintenance

### Daily
- Monitor modqueue
- Respond to modmail
- Engage with posts

### Weekly
- Review and approve wiki edits
- Check spam filter
- Post weekly update (if applicable)

### Monthly
- Review moderator activity
- Update sidebar links if needed
- Post monthly recap

---

## Official Links

| Platform | Link |
|----------|------|
| 🌐 Website | https://t27.ai/ |
| 📖 Documentation | https://t27.ai/docs/ |
| 📱 Reddit | https://www.reddit.com/r/t27ai/ |
| ✈️ Telegram | https://t.me/t27_lang |
| 𝕏 X (Twitter) | https://x.com/t27_lang |
| 💻 GitHub | https://github.com/gHashTag/trinity |
| 📜 Zenodo | https://zenodo.org/communities/trinity |

## Contact

For questions about subreddit setup, contact:
- Reddit: https://www.reddit.com/r/t27ai/
- Telegram: https://t.me/t27_lang
- X: https://x.com/t27_lang

---

**φ² + 1/φ² = 3**
