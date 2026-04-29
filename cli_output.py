import sys

escape: str = "\033"
ANSI_init: str = f"{escape}["
ANSI_end: str = f"{escape}[0m"


def ANSI_combine(options: list[str], text: str) -> str:
    options_combined = ""
    for option in options:
        if option == options[0]:
            options_combined += option
        else:
            options_combined += ";" + option
    return f"{ANSI_init}{options_combined}m{text}{ANSI_end}"


def parse_args() -> dict[str, str]:
    args: list[str] = sys.argv.copy()
    ANSI_options: str = ""
    for arg in args:
        if len(arg) > 0:
            match arg:
                case "-o":
                    arg_index: int = args.index(f"{arg}")
                    if arg_index == len(args) - 1:
                        raise ValueError("Missing options")
                    next_arg: str = args[arg_index + 1]
                    if len(next_arg) > 0:
                        ANSI_options = next_arg
                        args.pop(arg_index + 1)
                        args.pop(arg_index)
                        break
                    else:
                        raise ValueError("Missing options")
    return {"options": ANSI_options, "text": args[1]}


def ANSI_print() -> int:
    parsed_args: dict[str, str] = parse_args()
    ANSI_options: str = parsed_args["options"]
    if ANSI_options and len(ANSI_options) > 0:
        sys.stdout.write(
            ANSI_combine(options=[ANSI_options], text=parsed_args["text"]) + "\n"
        )
    return 0


def main() -> int:
    if ANSI_print() == 0:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(0) if main() == 0 else sys.exit(1)
