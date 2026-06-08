# Design principles

## 1. Treat prompts as software

Every agent, skill, and command should have:

- a stable identifier
- version history
- clear inputs and outputs
- tests or review prompts
- platform-specific build output generated from source

## 2. Separate entrypoint, role, and capability

- **Command**: what the user types; short and action-oriented.
- **Agent**: who performs the task; owns judgment and tradeoffs.
- **Skill**: how specialized work is done; owns method, references, scripts, and checklists.

Do not put a 500-line methodology into a command. Let the command route to an agent or skill.

## 3. Prefer durable method over magic words

Good assets explain why a step matters. Avoid brittle prompt incantations. Current models can generalize well when they understand intent, constraints, and failure modes.

## 4. Design for progressive disclosure

Keep always-loaded metadata short. Put long references in separate files and tell the model when to read them.

Recommended size:

- description: 50-150 words
- main instructions: under 500 lines
- references/scripts: unlimited, loaded only when needed

## 5. Make output contracts explicit

Every artifact should state the expected output shape. This makes results easier to evaluate and easier for users to consume.

## 6. Evaluate realistic prompts

Eval prompts should look like what a real user would type, including ambiguity, partial context, filenames, and messy wording. Avoid overly clean toy prompts.

## 7. Build for portability

Use neutral source YAML and generate platform-specific files. Avoid embedding platform syntax into the source unless it belongs in an adapter-specific override.
