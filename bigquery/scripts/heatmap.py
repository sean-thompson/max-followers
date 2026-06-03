"""
Heatmap renderer for GA4 spatial analytics data.
Reads cell data as JSON from stdin, outputs a 2D heatmap as a PNG image.

Usage:
    echo '[{"cell_x": 0, "cell_z": 0, "value": 100}, ...]' | python heatmap.py [options]

Options:
    --output PATH       Output file path (default: bigquery/output/heatmap.png)
    --title TEXT        Chart title (default: "Player Heatmap")
    --value-label TEXT  Label for the colour bar (default: "Player-Seconds")
    --grid-width N      Grid width in cells (auto-detected if omitted)
    --grid-height N     Grid height in cells (auto-detected if omitted)
    --min-x N           Starting cell X index (default: 0)
    --min-z N           Starting cell Z index (default: 0)
"""

import json
import sys
import argparse
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap


def main():
    parser = argparse.ArgumentParser(description='Render a heatmap from cell data')
    parser.add_argument('--output', default='bigquery/output/heatmap.png', help='Output file path')
    parser.add_argument('--title', default='Player Heatmap', help='Chart title')
    parser.add_argument('--value-label', default='Player-Seconds', help='Colour bar label')
    parser.add_argument('--grid-width', type=int, default=None, help='Grid width in cells')
    parser.add_argument('--grid-height', type=int, default=None, help='Grid height in cells')
    parser.add_argument('--min-x', type=int, default=0, help='Starting cell X index')
    parser.add_argument('--min-z', type=int, default=0, help='Starting cell Z index')
    args = parser.parse_args()

    # Read JSON from stdin
    data = json.load(sys.stdin)

    if not data:
        print('No data to render', file=sys.stderr)
        sys.exit(1)

    # Extract cell coordinates and values
    cells = [(d['cell_x'], d['cell_z'], d['value']) for d in data]

    # Determine grid bounds — use provided min or fall back to data min
    min_x = args.min_x
    min_z = args.min_z

    # Determine grid size — use provided or compute from data
    if args.grid_width:
        width = args.grid_width
    else:
        max_x = max(c[0] for c in cells)
        width = max_x - min_x + 1

    if args.grid_height:
        height = args.grid_height
    else:
        max_z = max(c[1] for c in cells)
        height = max_z - min_z + 1

    # Build the grid (initialise with zeros)
    grid = np.zeros((height, width))

    for cx, cz, val in cells:
        col = cx - min_x
        row = cz - min_z
        if 0 <= col < width and 0 <= row < height:
            grid[row][col] = val

    # Custom colour map: dark blue (cold) -> green -> yellow -> red (hot)
    colours = ['#0d0887', '#5302a3', '#8b0aa5', '#b83289',
               '#db5c68', '#f48849', '#febd2a', '#f0f921']
    cmap = LinearSegmentedColormap.from_list('heatmap', colours, N=256)

    # Render
    fig, ax = plt.subplots(1, 1, figsize=(max(8, width * 0.5), max(6, height * 0.5)))

    im = ax.imshow(grid, cmap=cmap, aspect='equal', origin='lower',
                   extent=[min_x - 0.5, min_x + width - 0.5,
                           min_z - 0.5, min_z + height - 0.5])

    ax.invert_xaxis()
    ax.set_xlabel('Cell X')
    ax.set_ylabel('Cell Z')
    ax.set_title(args.title)

    cbar = fig.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label(args.value_label)

    # Integer ticks if grid is small enough
    if width <= 30:
        ax.set_xticks(range(min_x, min_x + width))
    if height <= 30:
        ax.set_yticks(range(min_z, min_z + height))

    plt.tight_layout()
    plt.savefig(args.output, dpi=150, bbox_inches='tight')
    print(f'Heatmap saved to {args.output}')


if __name__ == '__main__':
    main()
