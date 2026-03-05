# docgen

Salesforce DX project scaffold.

## Quick start

Create a scratch org:

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias docgen-scratch --set-default
```

Push source:

```bash
sf project deploy start
```

Pull source (if you made changes in the org):

```bash
sf project retrieve start
```
