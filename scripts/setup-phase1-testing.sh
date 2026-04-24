#!/bin/bash
# githubclip GitHub MCP Testing - Quick Start Script
# Run this in your GitHub repository to set up Phase 1 testing

set -e

echo "🚀 githubclip GitHub MCP - Quick Start Testing"
echo "================================================"
echo ""

# Check prerequisites
echo "✓ Checking prerequisites..."
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Install: https://cli.github.com/"
    exit 1
fi

# Verify authentication
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi

echo "✓ GitHub CLI authenticated"

# Get repo info
REPO=$(gh repo view --json nameWithOwner -q)
OWNER=$(echo $REPO | cut -d'/' -f1)
REPO_NAME=$(echo $REPO | cut -d'/' -f2)

echo "✓ Repository: $REPO"
echo ""

# Verify git repo
if [ ! -d ".git" ]; then
    echo "❌ Not in a Git repository"
    exit 1
fi

echo "Step 1: Create test GitHub Project"
echo "===================================="
echo ""
echo "Creating test project 'githubclip Test'..."
echo ""
echo "Note: GitHub CLI doesn't support project creation yet."
echo "Please create manually:"
echo "  1. Go to: https://github.com/$OWNER/$REPO_NAME/projects"
echo "  2. Click 'New project'"
echo "  3. Name: 'githubclip Test'"
echo "  4. Template: 'Table'"
echo "  5. Create project"
echo ""
read -p "Press Enter once you've created the project..."

# Prompt for project number
read -p "Enter the project number (from URL: .../projects/N): " PROJECT_NUM

# Get project ID via GraphQL
echo ""
echo "Fetching project details..."
PROJECT_ID=$(gh api graphql -f query="
  query {
    organization(login: \"$OWNER\") {
      projectV2(number: $PROJECT_NUM) {
        id
      }
    }
  }
" -q '.data.organization.projectV2.id' 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Could not fetch project. Verify project number and try again."
    exit 1
fi

echo "✓ Project ID: $PROJECT_ID"
echo ""

# Create test issues
echo "Step 2: Create test issues"
echo "=========================="
echo ""
echo "Creating 5 test issues..."

ISSUE_IDS=()

# Issue 1: In Progress, High
ISSUE=$(gh issue create \
    --title "Test Backend Work" \
    --body "This is a test issue for Phase 1 validation" \
    --label "backend" \
    --json number \
    -q '.number')
ISSUE_IDS+=($ISSUE)
echo "✓ Issue #$ISSUE: In Progress, High"

# Issue 2: Todo, Medium
ISSUE=$(gh issue create \
    --title "Test Frontend Task" \
    --body "This is a test issue for Phase 1 validation" \
    --label "frontend" \
    --json number \
    -q '.number')
ISSUE_IDS+=($ISSUE)
echo "✓ Issue #$ISSUE: Todo, Medium"

# Issue 3: In Review, Low
ISSUE=$(gh issue create \
    --title "Review Documentation" \
    --body "This is a test issue for Phase 1 validation" \
    --json number \
    -q '.number')
ISSUE_IDS+=($ISSUE)
echo "✓ Issue #$ISSUE: In Review, Low"

# Issue 4: Done
ISSUE=$(gh issue create \
    --title "Completed Task" \
    --body "This is a test issue for Phase 1 validation" \
    --json number \
    -q '.number')
ISSUE_IDS+=($ISSUE)
echo "✓ Issue #$ISSUE: Done"

# Issue 5: Blocked
ISSUE=$(gh issue create \
    --title "Blocked Work" \
    --body "This is a test issue for Phase 1 validation" \
    --label "agent-blocked" \
    --json number \
    -q '.number')
ISSUE_IDS+=($ISSUE)
echo "✓ Issue #$ISSUE: Blocked"

echo ""
echo "Step 3: Add issues to Project"
echo "=============================="
echo ""
echo "NOTE: GitHub CLI doesn't support adding issues to projects yet."
echo "Please add manually:"
echo "  1. Go to: https://github.com/$OWNER/$REPO_NAME/projects/$PROJECT_NUM"
echo "  2. For each test issue #${ISSUE_IDS[0]}, #${ISSUE_IDS[1]}, etc.:"
echo "     - Click 'Add item' → select the issue"
echo "     - Set 'Status' field:"
echo "       • #${ISSUE_IDS[0]}: 'In Progress' + Priority: 'High'"
echo "       • #${ISSUE_IDS[1]}: 'Todo' + Priority: 'Medium'"
echo "       • #${ISSUE_IDS[2]}: 'In Review' + Priority: 'Low'"
echo "       • #${ISSUE_IDS[3]}: 'Done' + Priority: 'None'"
echo "       • #${ISSUE_IDS[4]}: 'In Progress' + Priority: 'High'"
echo ""
read -p "Press Enter once you've added all issues to the project..."

echo ""
echo "Step 4: Ensure fields exist in Project"
echo "======================================"
echo ""
echo "Verify your project has these fields:"
echo "  • Status (single-select): Todo, In Progress, In Review, Done, Canceled"
echo "  • Priority (single-select): Urgent, High, Medium, Low, None"
echo ""
echo "If missing, add them in Project Settings."
read -p "Press Enter once you've verified the fields..."

echo ""
echo "Step 5: Initialize githubclip"
echo "============================"
echo ""
echo "Now run in your Claude Code IDE:"
echo "  /githubclip-init"
echo ""
echo "When prompted:"
echo "  • Repo: $OWNER/$REPO_NAME"
echo "  • Project: Use 'githubclip Test' (number: $PROJECT_NUM)"
echo "  • Persona: Choose 'engineering'"
echo ""
read -p "Press Enter once you've run /githubclip-init..."

echo ""
echo "Step 6: Run dry-run test"
echo "======================="
echo ""
echo "Run in your Claude Code IDE:"
echo "  /heartbeat --dry-run"
echo ""
echo "Expected output:"
echo "  Dry run — would pick:"
echo "    #${ISSUE_IDS[0]} [backend] \"Test Backend Work\" (In Progress, High)"
echo ""
echo "  Queue:"
echo "    #${ISSUE_IDS[1]} [frontend] \"Test Frontend Task\" (Todo, Medium)"
echo ""
read -p "Press Enter once you've run /heartbeat --dry-run..."

echo ""
echo "✅ Phase 1 Setup Complete!"
echo ""
echo "Next steps:"
echo "  1. Verify dry-run output matches expected"
echo "  2. Read: docs/phases-1-4-testing-guide.md"
echo "  3. Run Phase 2-4 tests from the guide"
echo ""
echo "Test issues created: ${ISSUE_IDS[@]}"
echo "Project: https://github.com/$OWNER/$REPO_NAME/projects/$PROJECT_NUM"
