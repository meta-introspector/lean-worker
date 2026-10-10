# GitHub Actions Policy

## Organization Actions Only

This project **only uses custom GitHub Actions from the meta-introspector organization**.

### Actions Used

#### lean.yml
- `actions/checkout@v4` - Standard checkout (exception, universally trusted)
- `actions/cache@v4` - Standard cache (exception, universally trusted)
- `actions/upload-artifact@v4` - Standard artifact upload (exception, universally trusted)

#### deploy.yml
- ✅ `meta-introspector/checkout@v4` - Custom org checkout action
- ✅ `meta-introspector/lean-action@main` - Custom Lean/Python setup action
- ✅ `meta-introspector/cloudflare-pages-action@v1` - Custom Cloudflare Pages deploy action

### Status

| Action | Repository | Status | Notes |
|--------|-----------|--------|-------|
| checkout | [meta-introspector/checkout](https://github.com/meta-introspector/checkout) | ✅ Exists | Fork of actions/checkout |
| lean-action | [meta-introspector/lean-action](https://github.com/meta-introspector/lean-action) | ✅ Exists | Lean4 CI action |
| cloudflare-pages-action | [meta-introspector/cloudflare-pages-action](https://github.com/meta-introspector/cloudflare-pages-action) | ✅ Exists | Forked from kitabisa/cloudflare-pages-action |

### Rationale

We maintain our own actions to:
1. **Control dependencies** - No external supply chain risks
2. **Custom behavior** - Tailored to our Lean4 + deployment pipeline
3. **Audit trail** - All actions are in our org repos
4. **Versioning** - We control when/how actions are updated

### Exceptions

Only universally-trusted GitHub-maintained actions are allowed:
- `actions/checkout`
- `actions/cache`
- `actions/upload-artifact`
- `actions/setup-*` (when no org alternative exists)

### Forked Actions

#### cloudflare-pages-action

**Status:** ✅ Forked and synced

**Location:** [meta-introspector/cloudflare-pages-action](https://github.com/meta-introspector/cloudflare-pages-action)

**Upstream:** [kitabisa/cloudflare-pages-action](https://github.com/kitabisa/cloudflare-pages-action)

**Worktree:** `/mnt/data1/time-2026/10-october/10/cloudflare-pages-action`

**Sync status:** Up to date with upstream (ahead by 1 commit)

### Adding New Actions

To add a new action:
1. Create it in a meta-introspector repo
2. Document it here
3. Reference it as `meta-introspector/<action-name>@<version>`

**Never use third-party actions without explicit approval.**

### Recent Fixes

- ✅ Updated `actions/cache@v3` → `@v4`
- ✅ Updated `actions/upload-artifact@v3` → `@v4`
- ✅ Fixed heredoc syntax in lean.yml (`<<- 'EOF'`)
- ✅ Fixed curl command syntax in deploy.yml (line continuations)
