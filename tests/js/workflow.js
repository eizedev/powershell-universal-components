// The GitHub workflows of .github/workflows, parsed with the yaml package, for tests/js/ci.test.js.
import { readdirSync, readFileSync } from "node:fs";
import { parse } from "yaml";

const dir = new URL("../../.github/workflows/", import.meta.url);

/** The names of the workflow files. */
export const workflowFiles = () => readdirSync(dir).filter((name) => /\.ya?ml$/.test(name));

/** A workflow of .github/workflows, parsed. */
export const workflow = (file) => parse(readFileSync(new URL(file, dir), "utf8"));

/** The commands of a step's `run`, one per line, without comments and blank lines. */
export const commandsOf = (step) => String(step?.run ?? "").split("\n").map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));

/** Every string value of a parsed workflow, however deep: a `run`, a `with`, an `image`, an `env`. */
export const stringsOf = (value) => (typeof value === "string" ? [value] : value && typeof value === "object" ? Object.values(value).flatMap(stringsOf) : []);
