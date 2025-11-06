#include <libssh2.h>
#include <stdio.h>

int main(void)
{
    int rc = libssh2_init(0);
    if (rc != 0) {
        printf("libssh2_init failed: %d\n", rc);
        return 1;
    }
    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) {
        printf("libssh2_session_init returned null\n");
        libssh2_exit();
        return 1;
    }
    libssh2_session_free(session);
    libssh2_exit();
    printf("libssh2 init OK\n");
    return 0;
}
