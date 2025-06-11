# motoko emulator

<!--toc:start-->
- [motoko emulator](#motoko-emulator)
  - [Usage](#usage)
    - [Building](#building)
  - [Libraries](#libraries)
  - [Features](#features)
    - [6502](#6502)
      - [Instructions](#instructions)
  - [License](#license)
<!--toc:end-->

<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->

## Usage

Not a real usage here yet

### Building

Requires Zig `0.14.0`

```sh
git clone https://github.com/MotokoKusanagii/motoko.git
cd motoko
zig build
```

## Libraries

- [zig-gamedev](https://github.com/zig-gamedev/zig-gamedev)

## Features

### 6502

#### Instructions

|     | Instruction      | Assembler        |
|-----|------------------|------------------|
| LDA |:white_check_mark:|:white_check_mark:|
| STA |:white_check_mark:|:white_check_mark:|
| LDX |:white_check_mark:|:white_check_mark:|
| STX |:white_check_mark:|:white_check_mark:|
| LDY |:white_check_mark:|:white_check_mark:|
| STY |:white_check_mark:|:white_check_mark:|
| TAX |:white_check_mark:|:white_check_mark:|
| TXA |:white_check_mark:|:white_check_mark:|
| TAY |:white_check_mark:|:white_check_mark:|
| TYA |:white_check_mark:|:white_check_mark:|
| ADC |:white_check_mark:|:white_check_mark:|
| SBC |:white_check_mark:|:white_check_mark:|
| INC |:white_check_mark:|:white_check_mark:|
| DEC |:white_check_mark:|:white_check_mark:|
| INX |:white_check_mark:|:white_check_mark:|
| DEX |:white_check_mark:|:white_check_mark:|
| INY |:white_check_mark:|:white_check_mark:|
| DEY |:white_check_mark:|:white_check_mark:|
| ASL |:white_check_mark:|:white_check_mark:|
| LSR |:white_check_mark:|:white_check_mark:|
| ROL |:white_check_mark:|:white_check_mark:|
| ROR |:white_check_mark:|:white_check_mark:|
| AND |:white_check_mark:|:white_check_mark:|
| ORA |:white_check_mark:|:white_check_mark:|
| EOR |:white_check_mark:|:white_check_mark:|
| BIT |:white_check_mark:|:white_check_mark:|
| CMP |:white_check_mark:|:white_check_mark:|
| CPX |:white_check_mark:|:x:               |
| CPY |:white_check_mark:|:x:               |
| BCC |:x:               |:x:               |
| BCS |:x:               |:x:               |
| BEQ |:x:               |:x:               |
| BNE |:x:               |:x:               |
| BPL |:x:               |:x:               |
| BMI |:x:               |:x:               |
| BVC |:x:               |:x:               |
| BVS |:x:               |:x:               |
| JMP |:white_check_mark:|:x:               |
| JSR |:white_check_mark:|:x:               |
| RTS |:white_check_mark:|:x:               |
| BRK |:white_check_mark:|:x:               |
| RTI |:white_check_mark:|:x:               |
| PHA |:white_check_mark:|:x:               |
| PLA |:white_check_mark:|:x:               |
| PHP |:white_check_mark:|:x:               |
| PLP |:white_check_mark:|:x:               |
| TXS |:white_check_mark:|:x:               |
| TSX |:white_check_mark:|:x:               |
| CLC |:white_check_mark:|:x:               |
| SEC |:white_check_mark:|:x:               |
| CLI |:white_check_mark:|:x:               |
| SEI |:white_check_mark:|:x:               |
| CLD |:white_check_mark:|:x:               |
| SED |:white_check_mark:|:x:               |
| CLV |:white_check_mark:|:x:               |
| NOP |:white_check_mark:|:x:               |

## License

[GNU General Public License Version 3](LICENSE)
