/* font.h
	Multiple font support for the GameBoy
	Michael Hope, 1998
	michaelh@earthling.net
	Distrubuted under the Artistic License - see www.opensource.org
*/
#ifndef __FONT_H
#define __FONT_H

#include <gb.h>

/* Modes used in font_mode */
#define FONT_MODE_NOSCROLL	1	/* Dont scroll the screen */
#define FONT_MODE_NOINTERP	2	/* Dont interpret \n or others */

/* font_t is a handle to a font loaded by font_load() */
typedef UWORD font_t;

/* Init the font system */
void	font_init(void);
/* Load the font 'font' */
font_t	font_load( void *font );
/* Set the current font to 'font_handle', which was returned from an earlier
   font_load()
*/
font_t	font_set( font_t font_handle );
/* Simple hacks so that I dont break GBDK */
void	mprint_string( char *string );
void	mput_char( UBYTE text );
void	mgotoxy(UBYTE x, UBYTE y);

/* Print the same character 'show' 'num' times */
void print_repeat(char show, UBYTE num);

extern UBYTE font_mode;		/* printing mode - some of FONT_MODE_* above */
extern UBYTE font_fg_colour;	/* Foreground colour used in expanding compressed fonts */
extern UBYTE font_bg_colour;	/* Background colour - XOR'ed with fb_colour */

/* Internal representation of a font.  What a font_t really is */
typedef struct sfont_handle mfont_handle;
typedef struct sfont_handle *pmfont_handle;

struct sfont_handle {
	UBYTE first_tile;
	void *font;
};
	
#endif /* __FONT_H */
