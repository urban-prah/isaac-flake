/* Python serializes os.fork() through its GIL. Use native callers to cover
 * Kit's concurrent forks and the OpenBLAS atfork race from IsaacLab #8993.
 */
#define _GNU_SOURCE
#include <assert.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static pthread_barrier_t barrier;

static void *fork_worker(void *unused) {
    (void)unused;
    for (int attempt = 0; attempt < 12; ++attempt) {
        int code = pthread_barrier_wait(&barrier);
        assert(code == 0 || code == PTHREAD_BARRIER_SERIAL_THREAD);
        pid_t child = fork();
        assert(child >= 0);
        if (child == 0) _exit(0);
        int status = 0;
        assert(waitpid(child, &status, 0) == child);
        assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    }
    return NULL;
}

int main(int argc, char **argv) {
    assert(argc == 2);
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
    if (!library) {
        fprintf(stderr, "%s\n", dlerror());
        return 2;
    }
    assert(pthread_barrier_init(&barrier, NULL, 4) == 0);
    pthread_t workers[4];
    for (int i = 0; i < 4; ++i)
        assert(pthread_create(&workers[i], NULL, fork_worker, NULL) == 0);
    for (int i = 0; i < 4; ++i)
        assert(pthread_join(workers[i], NULL) == 0);
    assert(pthread_barrier_destroy(&barrier) == 0);
    puts("PASS: 4 native callers x 12 concurrent forks");
    return 0;
}
