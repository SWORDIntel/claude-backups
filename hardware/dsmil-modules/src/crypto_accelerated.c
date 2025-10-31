#include "../headers/tpm2_compat_accelerated.h"
#include <string.h>

tpm2_rc_t tpm2_crypto_init(tmp2_acceleration_flags_t accel_flags, tpm2_security_level_t min_security_level) {
    return TPM2_RC_SUCCESS;
}

tpm2_rc_t tpm2_crypto_finalize(void) {
    return TPM2_RC_SUCCESS;
}

tmp2_rc_t tmp2_create_primary_accelerated(ESYS_CONTEXT *esys_context,
                                        ESYS_TR parent_handle,
                                        const TPM2B_SENSITIVE_CREATE *in_sensitive,
                                        const TPM2B_PUBLIC *in_public,
                                        const TPM2B_DATA *outside_info,
                                        const TPML_PCR_SELECTION *creation_pcr,
                                        ESYS_TR *object_handle,
                                        TPM2B_PUBLIC **out_public,
                                        TPM2B_CREATION_DATA **creation_data,
                                        TPM2B_DIGEST **creation_hash,
                                        TPMT_TK_CREATION **creation_ticket,
                                        tmp2_acceleration_flags_t accel_flags) {
    return TPM2_RC_SUCCESS;
}