
const changelogLabels = new Set([
    "enhancement",
    "bug",
    "documentation",
    "deprecate",
    "remove"
]);

async function getLinkedPullRequests(github, issue) {
    const pullRequests = [];
    let cursor = null;

    const query = `
        query($id: ID!, $cursor: String) {
            node(id: $id) {
                ... on Issue {
                    closedByPullRequestsReferences(
                        first: 100
                        after: $cursor
                        includeClosedPrs: true
                    ) {
                        nodes {
                            number
                            merged
                        }
                        pageInfo {
                            hasNextPage
                            endCursor
                        }
                    }
                }
            }
        }
    `;

    while (true) {
        const result = await github.graphql(query, {
            id: issue.node_id,
            cursor
        });

        const connection = result.node.closedByPullRequestsReferences;

        pullRequests.push(...connection.nodes);

        if (!connection.pageInfo.hasNextPage) {
            return pullRequests;
        }

        cursor = connection.pageInfo.endCursor;
    }
}

module.exports = async ({ github, context, core }) => {
    const milestone = context.payload.pull_request.milestone;

    const issues = await github.paginate(github.rest.issues.listForRepo, {
        ...context.repo,
        milestone: String(milestone.number),
        state: "all",
        per_page: 100
    });

    const errors = [];

    for (const issue of issues) {
        if (issue.pull_request || issue.state_reason === "not_planned") {
            continue;
        }

        const prefix = `Issue #${issue.number} (${issue.html_url})`;

        if (issue.state_reason !== "completed") {
            errors.push(`${prefix}: issue is not completed`);
            continue;
        }

        const labels = issue.labels.map(label => label.name);

        if (labels.length === 0) {
            errors.push(`${prefix}: missing labels`);
        }

        const categories = labels.filter(label => changelogLabels.has(label));

        if (categories.length > 1) {
            errors.push(`${prefix}: multiple changelog labels: ${categories.join(", ")}`);
        }

        const pullRequests = await getLinkedPullRequests(github, issue);

        if (pullRequests.length === 0) {
            errors.push(`${prefix}: no linked pull requests`);
        } else {
            const unmerged = pullRequests.filter(pr => !pr.merged);

            if (unmerged.length > 0) {
                errors.push(
                    `${prefix}: unmerged pull requests: ${unmerged.map(pr => `#${pr.number}`).join(", ")}`
                );
            }
        }
    }

    if (errors.length > 0) {
        errors.forEach(error => core.error(error));
        throw new Error(`Milestone validation failed: ${errors.length} error(s)`);
    }

    core.info(`Milestone ${milestone.title}: all issues validated`);
};
