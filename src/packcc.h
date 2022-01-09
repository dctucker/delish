/* A packrat parser generated by PackCC 1.7.0 */

#ifndef PCC_INCLUDED_PACKCC_H
#define PCC_INCLUDED_PACKCC_H

#include "delikind.h"
struct deli_t {
        const char *input;
        size_t offset;
        size_t length;
        void *parser;
};
#ifdef __cplusplus
extern "C" {
#endif

typedef struct deli_context_tag deli_context_t;

deli_context_t *deli_create(struct deli_t *auxil);
int deli_parse(deli_context_t *ctx, int *ret);
void deli_destroy(deli_context_t *ctx);

#ifdef __cplusplus
}
#endif

#endif /* !PCC_INCLUDED_PACKCC_H */