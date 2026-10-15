const { writeFileSync } = require("node:fs");

const sections = new Map([
    ["enhancement", "Added"],
    ["bug", "Fixed"],
    ["deprecate", "Deprecated"],
    ["remove", "Removed"],
    // ["documentation", "Documentation"],
]);

module.exports = async ({ github, context }) => {
    const milestone = context.payload.pull_request.milestone;
    const version = process.env.VERSION;

    if (!milestone || !version) {
        throw new Error("Missing milestone or release version");
    }

    const issues = await github.paginate(github.rest.issues.listForRepo, {
        ...context.repo,
        milestone: String(milestone.number),
        state: "all",
        per_page: 100,
    });

    const changes = new Map(
        [...sections.values()].map((section) => [section, []]),
    );

    for (const issue of issues) {
        if (issue.state_reason !== "completed") {
            continue;
        }

        const label = issue.labels
            .map((label) => label.name)
            .find((label) => sections.has(label));

        if (!label) {
            continue;
        }

        changes
            .get(sections.get(label))
            .push(`- ${issue.title} ([#${issue.number}](${issue.html_url}))`);
    }

    const lines = [`# v${version}`];

    for (const [section, items] of changes) {
        if (items.length === 0) {
            continue;
        }

        lines.push("", `## ${section}`, "", ...items);
    }

    const filename = `changelog-${version}.md`;
    const totalChanges = lines.join("\n") + "\n";
    writeFileSync(filename, totalChanges);

    console.log(`Generated ${filename}`);
    console.log(`CHANGELOG: ${totalChanges}`);
};
