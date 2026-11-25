// docs/compatibility.md names the lowest PowerShell version the modules support; each module's
// manifest enforces it as PowerShellVersion. Both must say the same, so raising one raises the other.
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
