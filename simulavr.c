
/* This port corresponds to the "-W 0x20,-" command line option. */
#define special_output_port (*((volatile char *)0x20))

/* This port corresponds to the "-R 0x22,-" command line option. */
#define special_input_port  (*((volatile char *)0x22))

/* Poll the specified string out the debug port. */
void debug_puts(const char *str) {
  const char *c;

  for(c = str; *c; c++)
    special_output_port = *c;
}

/* Main for test program.  Enter a string and echo it. */
int main() {
  volatile char in_char;

  /* Output the prompt string */
  debug_puts("\nPress any key and enter:\n> ");

  /* Input one character but since line buffered, blocks until a CR. */
  in_char = special_input_port;

  /* Print the "what you entered:" message. */
  debug_puts("\nYou entered: ");

  /* now echo the rest of the characters */
  do {
    special_output_port = in_char;
  } while((in_char = special_input_port) != '\n');

  special_output_port = '\n';
  special_output_port = '\n';

  return 0;
}