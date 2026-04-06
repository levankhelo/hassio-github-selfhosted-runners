# hassio-github-selfhosted-runners

A Home Assistant add-on that lets you run a [GitHub Actions self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) directly on your Home Assistant device.

## Add-ons

### GitHub Self-Hosted Runner (`github_runner`)

Registers and starts a GitHub Actions self-hosted runner as a Home Assistant Supervisor add-on.

#### Configuration options

| Option | Required | Default | Description |
|---|---|---|---|
| `repo_url` | ✅ | – | URL of the GitHub repository **or** organisation to register the runner with (e.g. `https://github.com/your-org/your-repo`). |
| `runner_token` | ✅ | – | Runner registration token obtained from **GitHub → Repository → Settings → Actions → Runners → New self-hosted runner**. |
| `runner_name` | | `hassio-runner` | Display name shown for the runner in GitHub. |
| `labels` | | `self-hosted,hassio` | Comma-separated list of labels/tags to attach to the runner. |
| `runner_group` | | `Default` | Runner group to assign the runner to (organisations only; ignored for personal repositories). |
| `work_dir` | | `_work` | Working directory used by the runner for job check-outs. |
| `replace_existing` | | `true` | When `true`, automatically replaces an existing runner with the same name instead of failing. |

#### How to use

1. In GitHub, navigate to your repository (or organisation) → **Settings → Actions → Runners** and click **New self-hosted runner**.
2. Copy the **registration token** shown on that page.
3. Install this add-on in Home Assistant.
4. Set `repo_url` to your repository / organisation URL and paste the token into `runner_token`.
5. Start the add-on. The runner will download, register, and begin listening for jobs automatically.

> **Note:** Registration tokens are single-use and expire after one hour. If you restart the add-on after the token has been consumed you must generate a new token from GitHub.

#### Architecture support

`amd64` · `aarch64` · `armv7` · `armhf`
