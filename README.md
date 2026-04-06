# hassio-github-selfhosted-runners

A Home Assistant add-on that lets you run a [GitHub Actions self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) directly on your Home Assistant device.

### ⚠️ Security Notice

- This add-on runs a GitHub self-hosted runner. Any workflow job sent to this runner can execute arbitrary code on the Home Assistant host's add-on environment.
- Use this runner only for trusted private repositories or trusted organisation workflows.
- Prefer dedicated labels so only intended workflows can target this runner.
- The runner stores its local credentials in `/data/runner` so it can reconnect after restarts. Those files are persisted and should be treated as sensitive.
- After the first successful registration, you can clear `runner_token` from the add-on configuration. It is not needed for normal reconnects unless you are registering a new runner again.
- Avoid using the optional `packages` setting unless you explicitly need extra tools. Installing extra packages increases the attack surface.


## GitHub Self-Hosted Runner (`github_runner`)

Registers and starts a GitHub Actions self-hosted runner as a Home Assistant Supervisor add-on.

### Configuration options

| Option | Required | Default | Description |
|---|---|---|---|
| `repo_url` | ✅ | – | URL of the GitHub repository **or** organisation to register the runner with (e.g. `https://github.com/your-org/your-repo`). |
| `runner_token` | ✅ | – | Runner registration token obtained from **GitHub → Repository → Settings → Actions → Runners → New self-hosted runner**. |
| `runner_name` | | `hassio-runner` | Display name shown for the runner in GitHub. |
| `labels` | | `self-hosted,hassio` | Comma-separated list of labels/tags to attach to the runner. |
| `runner_group` | | `Default` | Runner group to assign the runner to (organisations only; ignored for personal repositories). |
| `work_dir` | | `_work` | Working directory used by the runner for job check-outs. |
| `replace_existing` | | `true` | When `true`, automatically replaces an existing runner with the same name instead of failing. |

### How to use

1. In GitHub, navigate to your repository (or organisation) → **Settings → Actions → Runners** and click **New self-hosted runner**.
2. Copy the **registration token** shown on that page.
3. Install this add-on in Home Assistant.
4. Set `repo_url` to your repository / organisation URL and paste the token into `runner_token`.
5. Start the add-on. The runner will download, register, and begin listening for jobs automatically.

> **Note:** Registration tokens are single-use and expire after one hour. With persistent storage enabled, the add-on only needs `runner_token` for the initial registration. After the runner has registered successfully and `/data/runner` contains the local runner state, later restarts reuse that state and do not need a fresh token.

### Architecture support
- `aarch64`: Raspberry Pi 3/4/5 running 64-bit Home Assistant OS, other ARM64 SBCs
- `amd64`: Intel/AMD x86_64 PCs, NUCs, mini PCs, servers, and virtual machines
- `armv7`: Raspberry Pi 2, Raspberry Pi 3 running 32-bit Home Assistant OS, other ARMv7 boards
- `armhf`: Older 32-bit ARM devices such as Raspberry Pi 1 and Zero-class hardware
