// docs/compatibility.md names the versions the modules support; each module's manifest enforces the
// lowest PowerShell as PowerShellVersion, and the start page's Requirements sum them up in one line.
// All must say the same, so raising one raises the others.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";

const root = new URL("../../", import.meta.url);

test("the PowerShell version on the compatibility page is every manifest's PowerShellVersion", () => {
    const page = readFileSync(new URL("docs/compatibility.md", root), "utf8");
    const documented = /^\| PowerShell \| (\d+\.\d+) or later\b/m.exec(page)?.[1];
    assert.ok(documented, 'docs/compatibility.md has no row "| PowerShell | <version> or later"');
    const modules = readdirSync(new URL("modules/", root), { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
    assert.ok(modules.length > 0, "no modules found");
    const versions = Object.fromEntries(modules.map((name) => {
        const manifest = readFileSync(new URL(`modules/${name}/${name}.psd1`, root), "utf8");
        return [name, /^\s*PowerShellVersion\s*=\s*'([^']+)'/m.exec(manifest)?.[1]];
    }));
    assert.deepEqual(versions, Object.fromEntries(modules.map((name) => [name, documented])), "raise the version in docs/compatibility.md and every manifest together");
});

test("the start page's Requirements name the versions of the compatibility page", () => {
    const page = readFileSync(new URL("docs/compatibility.md", root), "utf8");
    const psu = /^\| PowerShell Universal \| (\S+) and (\S+) \|/m.exec(page);
    const powershell = /^\| PowerShell \| (\d+\.\d+) or later\b/m.exec(page)?.[1];
    assert.ok(psu && powershell, "docs/compatibility.md: the PowerShell Universal or PowerShell row is not found");
    const start = readFileSync(new URL("docs/index.md", root), "utf8");
    const requirements = start.slice(start.indexOf("\n## Requirements\n"), start.indexOf("\n## ", start.indexOf("\n## Requirements\n") + 1));
    assert.ok(requirements.includes(`PowerShell Universal ${psu[1]} or ${psu[2]}`), `docs/index.md, Requirements: name PowerShell Universal ${psu[1]} or ${psu[2]}`);
    assert.ok(requirements.includes(`PowerShell ${powershell} or later`), `docs/index.md, Requirements: name PowerShell ${powershell} or later`);
});
