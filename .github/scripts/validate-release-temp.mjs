
import { readFileSync } from "node:fs";

const categories = new Set([
    "enhancement",
    "bug",
    "documentation",
    "deprecate",
    "remove"
]);

const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
const milestone = event.pull_request?.milestone;
const repository = process.env.GITHUB_REPOSITORY;
const token = process.env.GITHUB_TOKEN;

if (!milestone) {
    throw new Error("Release PR must have a milestone");
}

const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
};

async function request(url, body) {
    const response = await fetch(url, {
        method: body ? "POST" : "GET",
        headers,
        ...(body && {
            body: JSON.stringify(body),
            headers: {
                ...headers,
                "Content-Type": "application/json"
            }
        })
    });

    const data = await response.json();

    if (!response.ok || data.errors?.length) {
        throw new Error(JSON.stringify(data));
    }

    return data;
}

async function getMilestoneIssues() {
    const issues = [];

    for (let page = 1; ; page++) {
        const items = await request(
            `https://api.github.com/repos/${repository}/issues` +
            `?milestone=${milestone.number}&state=all&per_page=100&page=${page}`
        );

        issues.push(...items.filter(item => !item.pull_request));

        if (items.length < 100) {
            return issues;
        }
    }
}

async function hasMergedPullRequest(issueId) {
    const query = `
        query($id: ID!, $after: String) {
            node(id: $id) {
                ... on Issue {
                    closedByPullRequestsReferences(
                        first: 100
                        after: $after
                        includeClosedPrs: true
                    ) {
                        nodes {
                            mergedAt
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

    let after = null;

    do {
        const data = await request("https://api.github.com/graphql", {
            query,
            variables: { id: issueId, after }
        });

        const connection = data.data?.node?.closedByPullRequestsReferences;

        if (!connection) {
            throw new Error(`Cannot retrieve linked PRs for issue ${issueId}`);
        }

        if (connection.nodes.some(pr => pr.mergedAt !== null)) {
            return true;
        }

        if (!connection.pageInfo.hasNextPage) {
            return false;
        }

        after = connection.pageInfo.endCursor;
    } while (true);
}

const issues = await getMilestoneIssues();
const errors = [];

for (const issue of issues) {
    const prefix = `Issue #${issue.number}`;

    if (issue.state === "open") {
        errors.push(`${prefix}: issue is still open`);
        continue;
    }

    if (issue.state_reason === "not_planned") {
        continue;
    }

    if (issue.state_reason !== "completed") {
        errors.push(`${prefix}: issue is not completed`);
        continue;
    }

    const labels = issue.labels.map(label => label.name);

    if (labels.length === 0) {
        errors.push(`${prefix}: missing labels`);
    }

    const changelogLabels = labels.filter(label => categories.has(label));

    if (changelogLabels.length > 1) {
        errors.push(
            `${prefix}: multiple changelog labels: ${changelogLabels.join(", ")}`
        );
    }

    if (!(await hasMergedPullRequest(issue.node_id))) {
        errors.push(`${prefix}: no linked merged pull request`);
    }
}

if (errors.length > 0) {
    for (const error of errors) {
        console.error(`::error::${error}`);
    }

    process.exitCode = 1;
} else {
    console.log(`Milestone ${milestone.title} validated successfully`);
    console.log(`Checked ${issues.length} issues`);
}
