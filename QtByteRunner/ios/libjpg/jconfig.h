#define HAVE_PROTOTYPES
#define HAVE_UNSIGNED_CHAR
#define HAVE_UNSIGNED_SHORT
/* #define void char */
/* #define const */
#undef CHAR_IS_UNSIGNED
#define HAVE_STDDEF_H
#define HAVE_STDLIB_H
#undef NEED_BSD_STRINGS
#undef NEED_SYS_TYPES_H
#undef NEED_FAR_POINTERS
#undef NEED_SHORT_EXTERNAL_NAMES
#undef INCOMPLETE_TYPES_BROKEN

#ifdef JPEG_INTERNALS

#undef RIGHT_SHIFT_IS_UNSIGNED

//#define USE_MAC_MEMMGR		/* Define this if you use jmemmac.c */

#define ALIGN_TYPE long		/* Needed for 680x0 Macs */

#endif /* JPEG_INTERNALS */

#ifdef JPEG_CJPEG_DJPEG

#define TWO_FILE_COMMANDLINE	/* Binary I/O thru stdin/stdout doesn't work */

#undef DONT_USE_B_MODE
#undef PROGRESS_REPORT		/* optional */

#endif /* JPEG_CJPEG_DJPEG */