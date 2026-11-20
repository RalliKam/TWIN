# TWIN

TWIN is a two-panel file manager for Z80 computers running CP/M. Its
layout and keyboard-driven workflow are inspired by the classic Norton
Commander.

<img width="819" height="508" alt="Screenshot" src="https://github.com/user-attachments/assets/6907f9ee-4feb-4e7c-8f01-8aa106d03270" />

Update

Files with date

<img width="656" height="432" alt="Screenshot2" src="https://github.com/user-attachments/assets/96acd106-1f4b-49f7-9fa6-3e8b1fce1173" />


The program is written in Borland Turbo Pascal 3.0A for CP/M-80 and is
intended for CP/M 2.2 and CP/M 3.0. It uses a two-panel interface to
browse drives and perform common file operations without leaving the
program.

## Main screen

The screen is designed for an 80 × 24 character terminal.

- The left and right panels show the contents of two CP/M drives.
- At startup, the panels show drives A: and B:.
- The panel heading shows the drive letter and the number of files.
- Under CP/M 3.0, the heading also shows the drive's free space.
- File names appear on the left of each row. File sizes appear on the
  right, in KB rounded to whole numbers.
- The selected file is highlighted. The active panel is identified by
  an arrow in its heading.
- The command bar at the bottom lists the available keyboard commands.
- Status messages appear on the last line.

The panels use different heading colors to distinguish the active panel
from the inactive one. The file lists use a blue background with bold
white text; the selected name is shown in inverse video. The interface
uses ANSI/VT escape sequences for colors and highlighting.

## Keyboard commands

| Key | Command | Description |

| Up / Down          | Move selection  | Moves the highlight through the active panel's file list. The list scrolls when the selection reaches the visible panel edge. |
| `TAB`              | Switch panel   | Makes the other panel active. |
| `C` | Copy         | Copies the selected file to the same drive-independent filename on the other panel's drive. If a destination file already exists, TWIN asks before overwriting it. |
| `D` | Delete       | Asks for confirmation, then deletes the selected file from the active drive. |
| `R` | Rename       | Prompts for a new CP/M 8.3 filename, such as `NOTES.TXT`. |
| `S` | Show         | Opens the selected non-`.COM` file in the text viewer. |
| `L` | Change drive | Prompts for a drive letter from A: to P: and reloads the active panel. Press `ESC` to cancel. |
| `Q` | Quit         | Leaves TWIN and returns to CP/M. |

The arrow keys are read as ANSI/VT escape sequences. Their behavior
therefore depends on the terminal sending the expected cursor-key
sequences.

## File lists

Each panel displays up to 240 file names. The file names use the CP/M
8.3 format: up to eight characters for the name and three for the
extension, separated by a period.

The size shown for each file is calculated from its CP/M directory
entries. When a file uses multiple extents, TWIN combines those entries
into one row. Sizes are displayed in whole KB. Under CP/M 2.2, the
directory records describe the file in 128-byte records, so the displayed
size is an estimate rounded to KB. CP/M 3.0 also stores the byte count
used in the final record.

TWIN uses a flat CP/M directory listing; it does not provide
subdirectory navigation.

## Text viewer

Press `S` to display the selected file as text. `.COM` files are not
opened by the viewer. The viewer shows a page at a time and waits for a
key when the screen is full. Press `Q` or `ESC` at the page prompt to
leave the viewer.

The viewer is intended for text files. Non-printing control characters
may appear as dots or spaces.

## Requirements

- Z80-compatible computer or emulator
- CP/M 2.2 or CP/M 3.0
- Borland Turbo Pascal 3.0A for CP/M-80
- An 80 × 24 ANSI/VT-compatible terminal

Compile the program as a COM file in Turbo Pascal. TWIN uses ANSI/VT
escape sequences for screen colors and highlighting, so configure the
terminal or emulator for a compatible VT mode.

## Build Environment
No modern cross-compilers or emulators were used in the making of this binary. The source code is compiled natively on genuine vintage CPU: an Z80 computer running the original Turbo Pascal 3.0A compiler.

<img width="1632" height="1224" alt="grafik" src="https://github.com/user-attachments/assets/f760d255-1f72-48be-af13-0be68045b61a" />


## Project status

TWIN is a retrocomputing project under development. It is intended for
experimentation and use on classic Z80 and CP/M systems.

## License

This project is licensed under the [MIT License](LICENSE) - see the `LICENSE` file for details.

