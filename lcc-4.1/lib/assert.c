#include <stdio.h>
#include <stdlib.h>

static char rcsid[] = "$Id: assert.c,v 1.1.1.1 1999/10/17 17:55:51 michaelh Exp $";

int _assert(char *e, char *file, int line) {
	fprintf(stderr, "assertion failed:");
	if (e)
		fprintf(stderr, " %s", e);
	if (file)
		fprintf(stderr, " file %s", file);
	fprintf(stderr, " line %d\n", line);
	fflush(stderr);
	abort();
	return 0;
}
