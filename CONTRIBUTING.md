# Contributing Guide

Thank you for your interest in improving these setup scripts! This guide will help you contribute effectively.

## 🌟 Ways to Contribute

1. **Report Issues** - Found a bug? Let us know!
2. **Suggest Features** - Have an idea? Share it!
3. **Improve Documentation** - Help make the docs better
4. **Add Support** - New distro or package manager support
5. **Fix Bugs** - Submit bug fixes
6. **Optimize Scripts** - Make them faster or more reliable

## 🛠️ Development Setup

1. **Fork the repository**
2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/MY_OWN_REPO-s.git
   cd MY_OWN_REPO-s
   ```
3. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📝 Coding Guidelines

### Script Best Practices

1. **Use proper shebang:**
   ```bash
   #!/bin/bash
   # or
   #!/usr/bin/env bash
   ```

2. **Enable strict mode:**
   ```bash
   set -euo pipefail
   ```

3. **Add comments:**
   ```bash
   # --------------------------------------------------------------
   # Clear section description
   # --------------------------------------------------------------
   echo "User-friendly step description..."
   # Actual commands
   ```

4. **Handle errors:**
   ```bash
   if ! command -v tool &> /dev/null; then
       echo "Error: tool not found"
       exit 1
   fi
   ```

5. **Make scripts idempotent:**
   - Scripts should be safe to run multiple times
   - Check if packages are already installed
   - Use `|| true` for non-critical commands

### Documentation Guidelines

1. **Keep README.md updated** with any new features
2. **Update COMPARISON.md** if adding new scripts
3. **Add to CUSTOMIZATION.md** if adding configurable options
4. **Use clear examples** in documentation
5. **Include troubleshooting tips** for common issues

### Testing

Before submitting, test your changes:

1. **Test in a clean environment:**
   - Use a virtual machine
   - Test on the target distribution

2. **Check script syntax:**
   ```bash
   bash -n your_script.sh
   ```

3. **Test error handling:**
   - Interrupt the script and verify behavior
   - Test with missing dependencies

4. **Verify idempotency:**
   - Run the script twice
   - Ensure it handles already-installed packages

## 🔄 Pull Request Process

1. **Update documentation** as needed
2. **Test thoroughly** on target systems
3. **Write clear commit messages:**
   ```
   Add support for Fedora setup
   
   - Create new fedora_setup.sh script
   - Add DNF package installation
   - Update README with Fedora instructions
   ```

4. **Create pull request:**
   - Describe what you changed and why
   - Reference any related issues
   - Include testing notes

5. **Respond to feedback:**
   - Address review comments
   - Make requested changes
   - Keep the conversation constructive

## 🎯 Project Goals

When contributing, keep these goals in mind:

1. **Simplicity** - Scripts should be easy to understand
2. **Reliability** - Must work consistently
3. **Safety** - Don't break existing systems
4. **Clarity** - Code and docs should be clear
5. **Maintainability** - Easy for others to modify

## 📋 Checklist for New Scripts

If adding a new setup script:

- [ ] Script has proper shebang and strict mode
- [ ] Clear step-by-step comments
- [ ] Error handling for critical operations
- [ ] Idempotent (safe to run multiple times)
- [ ] Git configuration section
- [ ] Package installation sections organized
- [ ] Final completion message
- [ ] Executable permissions (`chmod +x`)
- [ ] Added to README.md
- [ ] Added to COMPARISON.md
- [ ] Added usage instructions
- [ ] Tested on target distribution

## 🐛 Bug Reports

Good bug reports include:

1. **Distribution and version:** "Ubuntu 22.04 LTS"
2. **Script used:** "ubuntu_setup_snap.sh"
3. **What you expected:** "Discord should install"
4. **What actually happened:** "Snap install failed"
5. **Error messages:** Full error output
6. **Steps to reproduce:** Detailed steps
7. **Logs:** Relevant log files (e.g., `~/ubuntu-setup.log`)

## 💡 Feature Requests

Good feature requests include:

1. **Clear description:** What feature you want
2. **Use case:** Why this feature is useful
3. **Example:** How it would work
4. **Impact:** Who would benefit

## 🏗️ Adding New Distribution Support

To add a new Linux distribution:

1. **Create new script:** `scripts/distro_setup.sh`
2. **Follow existing structure:**
   - System updates
   - Package installation
   - Application setup
   - Git configuration
   - Completion message

3. **Update documentation:**
   - Add to README.md
   - Add to COMPARISON.md
   - Add to QUICK_REFERENCE.md

4. **Test thoroughly** on the target distro

## 🤝 Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on what's best for the project
- Show empathy towards others

## 📄 License

By contributing, you agree that your contributions will be licensed under the same terms as the project.

## ❓ Questions?

If you have questions about contributing:

1. Check existing documentation
2. Look at closed issues and PRs
3. Open a new issue with the "question" label

## 🙏 Thank You!

Every contribution, no matter how small, is valuable. Thank you for helping improve these scripts!
