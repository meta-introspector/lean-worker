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
- ⚠️  `meta-introspector/cloudflare-pages-action@v1` - **MISSING - needs to be created**

### Status

| Action | Repository | Status | Notes |
|--------|-----------|--------|-------|
| checkout | [meta-introspector/checkout](https://github.com/meta-introspector/checkout) | ✅ Exists | Fork of actions/checkout |
| lean-action | [meta-introspector/lean-action](https://github.com/meta-introspector/lean-action) | ✅ Exists | Lean4 CI action |
| cloudflare-pages-action | meta-introspector/cloudflare-pages-action | ❌ Missing | **TODO: Create this action** |

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

### Missing Actions

#### cloudflare-pages-action

**Status:** Does not exist yet

**Needed for:** deploy.yml Cloudflare Pages deployment

**Options:**
1. Create `meta-introspector/cloudflare-pages-action` repo
2. Fork `cloudflare/pages-action` to our org
3. Replace with direct wrangler CLI commands in workflow

**Recommended:** Fork `cloudflare/pages-action` to maintain control while preserving functionality.

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
