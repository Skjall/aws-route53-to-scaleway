# Contributing to AWS Route53 to Scaleway DNS Migration

Thank you for your interest in contributing to this project! This document provides guidelines for contributing to the AWS Route53 to Scaleway DNS Migration tool.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include details about your configuration and environment

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Development Guidelines

### Code Style

* Follow the existing code style
* Use meaningful variable names
* Comment complex logic
* Maintain backward compatibility

### Testing

* Test your changes thoroughly
* Include any new dependencies in the README
* Ensure the script works with different domain scenarios
* Test with both valid and invalid inputs

### Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

## Project Structure

```
.
├── scaleway-dns-migration.sh    # Main migration script
├── README.md                 # Project documentation
├── LICENSE                   # MIT License
├── CONTRIBUTING.md           # This file
├── .github/
│   ├── workflows/
│   │   └── test.yml         # GitHub Actions workflow
│   └── ISSUE_TEMPLATE/      # Issue templates
└── examples/                # Example configurations
```

## Recognition

Contributors will be recognized in the README.md file.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing to make DNS migration easier for everyone! 🚀