#include "delikind.h"

#define YY_DEBUG

#undef YY_INPUT
#define YY_INPUT(b,r,s) readYYInput(b,&r,s)

const char *yyDeliScript;
size_t yyReadOffset;
int yyDeliScriptLen;

void yySetScript( char *cstr )
{
	yyDeliScript = cstr;
	yyDeliScriptLen = strlen(cstr);
	printf("received cstr len %d\n", yyDeliScriptLen);
	yyReadOffset = 0;
}

void readYYInput( char *buf, int *result, int max_size )
{
    int readable = max_size;
    int remaining = yyDeliScriptLen - yyReadOffset;

	if( readable > remaining )
		readable = remaining;
	for( int i=0; i < readable; i++ )
	{
		buf[i] = yyDeliScript[yyReadOffset + i];
	}
	//printf("Reading %c of %d\n", yyDeliScript[yyReadOffset], max_size);

	*result = readable;
	yyReadOffset += readable;
}

/*
int level = 0;
void yyenter(enum DeliKind kind)
{
	level++;
	for(int i=0; i < level; i++)
		printf(" ");
	printf("> ");
	something(kind, "", 0);
}
void yyleave(enum DeliKind kind)
{
	for(int i=0; i < level; i++)
		printf(" ");
	printf("< ");
	something(kind, "", 0);
	level--;
}
*/
