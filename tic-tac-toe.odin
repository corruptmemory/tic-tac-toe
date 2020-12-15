package main

import "flags"

main :: proc() {
    parser := flags.new_parser();
    flags.add_flag(&parser,'a',"This is the A argument",int);
    flags.add_flag(&parser,'b',"This is the B argument",int,10);
    flags.add_flag(&parser,'c',"--long-c","This is the C argument",string,"The C argument");

}
