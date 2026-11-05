import { createRequire } from 'node:module';

// The preset is loaded here, not named in parserPreset, so its parser options
// can be built with issuePrefixes overridden. A parserPreset.parserOpts object
// in config does not merge into this preset: the preset exports its options
// from a function, which the config merge replaces wholesale, leaving the
// parser on a default header pattern with no `!?` that rejects `feat!: x`.
//
// `require`, not `import`: the module resolves through NODE_PATH, which the
// nix commitlint wrapper points at its own node_modules, and ESM resolution
// ignores NODE_PATH. The preset is then always the one the running commitlint
// bundles. If a commitlint without that NODE_PATH runs this file, the require
// throws instead of linting against something else.
const require = createRequire(import.meta.url);
const createPreset = require('conventional-changelog-conventionalcommits').default;

export default {
  extends: ['@commitlint/config-conventional'],
  parserPreset: {
    // The parser reads any `#N` followed by more text, on a body line after
    // the first, as an issue reference that opens the footer, so a body that
    // cites an issue mid-paragraph trips footer-leading-blank. A prefix no
    // commit ever writes turns reference parsing off. An empty list would be
    // simpler but also stops the rule catching a real `BREAKING CHANGE:`
    // footer with no blank line above it; this form keeps that.
    parserOpts: createPreset({ issuePrefixes: ['#ref-never-used-'] }).parser,
  },
  rules: {
    // Bodies routinely carry long paths, URLs and code fences that cannot be
    // wrapped at 100 chars. Subject-length checks remain in effect.
    'body-max-line-length': [0, 'always', Infinity],
  },
};
