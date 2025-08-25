# Documentation Filing Rules 📚 MANDATORY

## Core Principle

**ALL documentation MUST be filed in the `docs/` folder - NO EXCEPTIONS**

## Directory Structure

```
docs/
├── fixes/              # Bug fixes and patches
├── features/           # New features and enhancements  
├── guides/             # User guides and tutorials
├── technical/          # Technical specifications
├── archived/           # Deprecated documentation
└── README.md          # Main documentation index
```

## Filing Rules

### 1. Never Leave Docs in Root
❌ **WRONG**: `/project/NEW_FEATURE.md`
✅ **RIGHT**: `/project/docs/features/NEW_FEATURE.md`

### 2. Choose Correct Subfolder
- **Bug fix?** → `docs/fixes/`
- **New feature?** → `docs/features/`
- **How-to guide?** → `docs/guides/`
- **Technical spec?** → `docs/technical/`
- **Old/deprecated?** → `docs/archived/`

### 3. Naming Conventions
- Use descriptive names: `BASH_OUTPUT_FIX.md` not `fix.md`
- Include dates for time-sensitive: `2025-08-25-wrapper-update.md`
- Use CAPS for important docs: `CRITICAL_SECURITY_FIX.md`
- Hyphens for multi-word: `database-migration-guide.md`

### 4. Always Update Index
After adding any documentation:
1. Open `docs/README.md`
2. Add entry in appropriate section
3. Include brief description
4. Add date if relevant

### 5. Cross-References
At the bottom of each doc, add:
```markdown
## Related Documentation
- [Link to related doc 1](../path/to/doc1.md)
- [Link to related doc 2](../path/to/doc2.md)
```

## Examples

### Creating Fix Documentation
```bash
# Create the document
echo "# Fix Title" > docs/fixes/2025-08-25-bash-output-fix.md

# Update the index
# Edit docs/README.md and add under "Recent Documentation Updates"
```

### Creating Feature Documentation
```bash
# For single feature
docs/features/new-agent-system.md

# For complex feature with multiple docs
docs/features/tandem-orchestration/
├── overview.md
├── architecture.md
└── api-reference.md
```

## Enforcement

This policy is enforced through:
1. **CLAUDE.md** - Contains mandatory documentation guidelines
2. **Code reviews** - All PRs checked for proper doc filing
3. **Automation** - Scripts to detect misplaced docs
4. **AI Assistant** - Claude will automatically file docs correctly

## Quick Checklist

Before committing documentation:
- [ ] Is it in `docs/` folder?
- [ ] Is it in the correct subfolder?
- [ ] Does it have a descriptive filename?
- [ ] Did you update `docs/README.md`?
- [ ] Did you add cross-references?
- [ ] Does it follow markdown standards?

## Violations

Documentation found in root directory will be:
1. Automatically moved to appropriate `docs/` subfolder
2. Logged as a policy violation
3. Creator notified to follow guidelines

---

*Policy Effective: 2025-08-25*
*Last Updated: 2025-08-25*
*Status: MANDATORY - All contributors must follow*