#ifndef ANCILLARY_H
#define ANCILLARY_H

#ifdef __cplusplus
extern "C" {
#endif

int ancil_send_fd(int sock, int fd);
int ancil_recv_fd(int sock, int *fd);

#ifdef __cplusplus
}
#endif

#endif
