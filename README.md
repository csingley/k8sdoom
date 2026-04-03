# k8sdoom 🔫☸️

Dedicated to the memory of David Emory Watson, computer scientist.

**k8sdoom** is a gamified Kubernetes administration tool that lets you manage your cluster by playing Doom. It turns your Kubernetes nodes into interactive monsters, allowing you to perform administrative tasks like tainting and draining nodes through retro-FPS gameplay.

Based on [psdoom-ng](https://github.com/keymon/psdoom-ng), this version has been specifically modified for Kubernetes and packaged for modern, distro-agnostic use.

---

## How it Works

*   **Monsters = Nodes**: Every monster in the game represents a real Kubernetes node in your cluster.
*   **Wounding = Tainting**: Damaging a monster triggers a `kubectl taint nodes <node> psdoom=taint:NoSchedule`, preventing new pods from being scheduled.
*   **Killing = Draining**: Killing a monster executes a `kubectl drain <node>`, safely evicting all pods for maintenance.
*   **Monster Types = Node Status**:
    *   **Shotgun Guy**: A healthy, `Ready` node.
    *   **Pinky Demon**: A `NotReady` node.
    *   **Hell Knight**: A node already tainted with `NoSchedule`.
    *   **Arch-vile**: An `Unschedulable` node.
    *   **Zombieman**: Default status.

---

## Installation

### Prerequisites

You will need the following tools in your `PATH`:
*   `kubectl` (configured with access to a cluster)
*   `jq`
*   `git`, `curl`, `unzip`
*   Development headers for `SDL 1.2`, `SDL_mixer`, and `SDL_net` (Optional: The Makefile will automatically download and build these locally if not found).

### Build and Install

```bash
git clone https://github.com/csingley/k8sdoom.git
cd k8sdoom
make install
```

This will:
1.  Detect (or build) required SDL 1.2 dependencies.
2.  Clone and patch the `psdoom-ng` source.
3.  Download the **Freedoom** WAD assets.
4.  Install the binary and wrapper to `~/.local/bin` and assets to `~/.local/share/k8sdoom`.

---

## Usage

Ensure `~/.local/bin` is in your `PATH`, then run:

```bash
k8sdoom
```

The game will automatically launch the node poller and map your cluster to the E1M1 courtyard.

### Customization

You can override the default Kubernetes commands via environment variables:
*   `PSDOOMKILLCMD`: Command to run when a monster is killed (default: `kubectl drain ...`)
*   `PSDOOMRENICECMD`: Command to run when a monster is wounded (default: `kubectl taint ...`)

---

## Uninstall

To remove all binaries and data files:

```bash
make uninstall
```

## Credits

*   Originally based on [psdoom-ng](https://github.com/keymon/psdoom-ng) by keymon.
*   Inspired by the original `psdoom` by Dennis Chao.
*   Powered by [Freedoom](https://freedoom.github.io/) assets.

---

**Disclaimer**: This tool performs real administrative actions on your Kubernetes cluster. Use with caution (and a steady aim).
