"""Nick's gradient-ascent (mountain-climbing) clustering algorithm"""

cimport cython
import numpy as np
cimport numpy as np

import random, time
from extlib import threadpool
from multiprocessing import cpu_count

cdef extern from "math.h":
    double sqrt(double x) nogil
    double fabs(double x) nogil
    double exp(double x) nogil
    double ceil(double x) nogil

cdef extern from "stdio.h":
    int printf(char *, ...) nogil
    cdef void *malloc(size_t) nogil # allocates without clearing to 0
    cdef void *calloc(size_t, size_t) nogil # allocates with clearing to 0
    cdef void free(void *) nogil

cdef extern from "string.h":
    cdef void *memset(void *, int, size_t) nogil # sets n bytes in memory to constant

# NOTE: stdout is buffered by default in linux. This means anything printed to screen from
# within C code won't show up until it gets a newline, or until you call fflush(stdout).
# Unbuffered output can be forced by running Python with the "-u" switch


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def climb(np.ndarray[np.float32_t, ndim=2, mode='c'] data,
          double sigma=0.05, double alpha=2.0, double rmergex=1.0,
          double rneighx=4,
          double minmove=-1.0, int maxstill=100, int maxnnomerges=1000,
          int minpoints=10):
    """Implement Nick's gradient ascent (mountain climbing) clustering algorithm
    TODO:
        - reverse annealing sigma: starting small, and gradually increase it over iters
            - increase it a bit every time you get an iteration with no mergers?
        - maybe some way of making sigma dynamic for each scout and for each iteration?
        - maybe annealing of alpha (decreasing it over time)? NVS sounds skeptical

        - classify obvious wide flat areas as noise points that shouldn't be clustered:
            - track the distance each point has travelled during the course of the algorithm.
            When done, plot the distribution of travel distances, and maybe you'll get something
            bimodal, and choose a cutoff travel distance past which any point that travelled
            further is considered a noise point
            - or maybe plot distribution of travel times
            - use some cutoff of local density to specify what's noise and what isn't? skeptical..

        - visualize algorithm in real time to see what exactly it's doing, and why some clusters
        are split while others are merged

        - instead of merging the higher indexed scout into the lower indexed one, you should
        really merge the one with the lower density estimate into the one with the higher
        density estimate - otherwise you potentially end up deleting the scout that's closer
        to the local max density, which probably sets you back several iterations
            - this would require calc'ing and storing the density for each cluster, and updating
            it every time it moves
                - is local density and local gradient calc sufficiently similar that this won't
                be expensive?
            - find whichever has the biggest density estimate - if it's not the lowest indexed
            scout (which will be the case 50% of the time), swap the entries in all the arrays
            (scouts, still, etc) except for the cids array, then proceed as usual. Then update
            the density for the newly merged cluster

        - try using simplex algorithm for scout position update step, though that might miss
        local maxima

        - rescale all data by 2*sigma so you can get rid of the div by twosigma2 operation?
            - only applies to Gaussian kernel, not Cauchy

        - try using the n nearest neighbours to calculate gradient, instead of a guassian with
        a sigma. This makes it scale free, but NVS says this often results in situations where
        the gradient is 0 for some reason

        - scale x not just by its std, but also according to some absolute multiple of space
        (say 1.0 is 50 um), such that recordings with wider or narrower x locations (2 or 3
        column probes) will cluster roughly as well with a constant sigma value (like 0.25,
        which really means you can expect up to 4 clusters along the x axis)

    DONE:
        - turn off checks for ZeroDivisionError, though I doubt that slows things down much
        - keep track of max movement on each iter, use consistently low max movement as
          automatic exit criteria
            - alternative: keep track of how long it's been since the last scout merger, and
            exit based on that
        - add freezing of points, for speed?
            - when a scout point has moved less than some distance per iteration for all of
            the last n iterations, freeze it. Then, in the position update loop, check for
            frozen scout points
        - add subsampling to reduce initial number of scout points
        - NVS - to weed out potential noise spikes, for each cluster, find the local density
        of the scout point at the max, then reject all other data points in that cluster whose
        ocal density falls below, say, 1% of the max. Apply it as a mask, so you can tweak that
        1% value as you wish, without having to run the whole algorithm all over again
        - delete scouts that have fewer than n points (at any point during iteration?)
        - multithread scout update and assignment of unclustered points step
    """
    cdef int N = len(data) # total num data points
    cdef int ndims = data.shape[1] # num cols in data
    cdef int M # current num scout points (clusters)
    cdef int npoints, npointsremoved, nclustsremoved
    
    # scouts table starts out as just a copy of float data table
    cdef np.ndarray[np.float32_t, ndim=2, mode='c'] scouts = data.copy() # stores scout positions
    
    # need to first convert data table to something suitable for truncing to easily get
    # ints. First have to add some offset to make everything +ve. Then, divide by your fraction
    # of sigma that you want to discretize by. Then, when returning scout positions, need to do 
    # the inverse
    mindata = min(data)
    data -= mindata # offset data to be +ve starting from 0
    binx = 0.1 # some fraction of sigma to bin data by
    binsize = binx * sigma
    data /= binsize # scale data
    assert data.max() < 2**32
    assert data.min() >= 0
    data = np.uint32(data) # trunc to uint32

    # get dimensions of sparse matrices
    cdef np.ndarray[np.uint32_t, ndim=1, mode='c'] dims = np.zeros(ndims, dtype=np.uint32)
    for dimi in range(ndims):
        dims[dimi] = max(data[:, dimi])
    
    # ndim static histogram of point positions in data, bins of size binsize
    # use uint16, since not likely to have more than 65k points in a single bin.
    # Hell, maybe uint8 would work too
    #cdef np.ndarray[np.uint16_t, ndim=ndims, mode='c'] datah = np.zeros(dims, dtype=np.uint16)
    cdef unsigned short *datah = <unsigned short *>calloc(prod(dims), sizeof(unsigned short))
    for i in range(N):
        j = ndi2li(data[pi]) # convert ndim index to linear index
        datah[j] += 1
        if datah[j] == 2**16 - 1:
            raise RuntimeError("uint16 isn't enough for datah!")
    
    ## unravel_index and ravel_multi_index are useful!
    
    # ndim dynamic histogram of scout positions in scouts table
    # use dynamic scoutspace sparse matrix to approximate each scout's position and
    # calculate gradient according to same sized datah, but then update the scout's
    # actual position in separate scouts table in float, per usual. Otherwise, if you
    # stored scout positions quantized, you could easily get stuck in a bin and never
    # get out, because you could never accumulate less than bin sized changes in position
    print('creating %d MB scoutspace matrix' % (dims.prod() * 4 / 1e6))
    #cdef np.ndarray[np.uint32_t, ndim=ndims, mode='c'] scoutspace = np.zeros(dims, dtype=np.uint32)
    cdef unsigned int *scoutspace = <unsigned int *>calloc(prod(dims), sizeof(unsigned int))

    # for merging scouts, clear scoutspace, and start writing their indices to it.
    # While writing, if you find the position in the matrix is already occupied,
    # then obviously you need to merge the current scout into the one that's already
    # there. Once you're done filling the matrix, for every non-zero entry (which you can
    # quickly find by truncing scout position in scouts array to get its index)
    # take slice corresponding to rmerge, then maybe do sum of squared discrete distances,
    # and merge if < rmerge

    # cluster indices into data:
    cdef np.ndarray[np.int32_t, ndim=1, mode='c'] cids = np.zeros(N, dtype=np.int32)
    # for each scout, num consecutive iters without significant movement:
    ## TODO: should check that (maxstill < 256).all(), or use uint16 instead:
    cdef np.ndarray[np.uint8_t, ndim=1, mode='c'] still = np.zeros(N, dtype=np.uint8)
    cdef double sigma2 = sigma * sigma
    #cdef double twosigma2 = 2 * sigma2
    cdef double rmerge = rmergex * sigma # radius within which scout points are merged
    cdef double rmerge2 = rmerge * rmerge
    cdef double rneigh = rneighx * sigma # radius around scout to include data for gradient calc
    cdef double rneigh2 = rneigh * rneigh
    cdef double d, d2, minmove2
    cdef Py_ssize_t i, j, k, scouti, clustii
    cdef int iteri=0, nnomerges=0, Mthresh, ncpus
    cdef bint incstill, merged=False, continuej=False

    M = N # initially, but M will decrease over time
    Mthresh = 3000000 / N / ndims
    print("Mthresh = %d" % Mthresh)
    cids = np.arange(M, dtype=np.int32)

    if minmove == -1.0:
        # TODO: should minmove also depend on sqrt(ndims)? it already does via sigma
        minmove = 0.000001 * sigma * alpha # in any direction in ndims space
    minmove2 = minmove * minmove

    ncpus = cpu_count()
    cdef long *lohi = <long *>malloc((ncpus+1)*sizeof(long))
    pool = threadpool.ThreadPool(ncpus)

    while True:

        if nnomerges == maxnnomerges:
            break

        # merge pairs of scout points sufficiently close to each other
        i = 0
        while i < M:
            j = i+1
            while j < M:
                if still[i] == maxstill and still[j] == maxstill: # both scouts are frozen
                    j += 1
                    continue
                # for each pair of scouts, check if any pair is within rmerge of each other
                d2 = 0.0 # reset
                for k in range(ndims):
                    d = fabs(scouts[i, k] - scouts[j, k])
                    if d > rmerge: # break out of k loop, continue to next j
                        continuej = True
                        break # out of k loop
                    d2 += d * d
                if continuej:
                    continuej = False # reset
                    j += 1
                    continue # to next j loop
                if d2 <= rmerge2:
                    # merge the scouts: keep scout i, ditch scout j
                    # shift all entries at j and above in scouts array down by one
                    for scouti in range(j, M-1):
                        for k in range(ndims):
                            scouts[scouti, k] = scouts[scouti+1, k]
                        still[scouti] = still[scouti+1] # ditto for still array
                    # update cluster indices
                    for clustii in range(N):
                        if cids[clustii] == j:
                            cids[clustii] = i # overwrite all occurences of j with i
                        elif cids[clustii] > j:
                            cids[clustii] -= 1 # decr all clust indices above j
                    M -= 1 # decr num scouts, don't inc j, new value at j has just slid into view
                    #printf(' %d<-%d ', i, j)
                    merged = True
                else:
                    j += 1
            i += 1
        if merged: # at least one merger happened on this iter
            printf('M')
            nnomerges = 0 # reset
            merged = False # reset
        else: # no mergers happened on this iter
            nnomerges += 1 # inc

        # move scouts up their local density gradient
        if M < Mthresh: # use a single thread
            move_scouts(0, M, scouts, data, still,
                        N, ndims, sigma2, alpha,
                        rneigh, rneigh2, minmove2, maxstill)
        else: # use multiple threads
            span(lohi, 0, M, ncpus) # modify lohi in place
            for i in range(ncpus):
                args = (lohi[i], lohi[i+1], scouts, data, still,
                        N, ndims, sigma2, alpha,
                        rneigh, rneigh2, minmove2, maxstill)
                req = threadpool.WorkRequest(move_scouts, args)
                pool.putRequest(req)
            pool.wait()
        printf('.')

        iteri += 1

    printf('\n')

    pool.terminate()
    free(datah)
    free(scoutspace)
    free(lohi)

    # remove clusters with less than minpoints
    npointsremoved = 0
    nclustsremoved = 0
    i = 0
    while i < M:
        npoints = 0 # reset
        for j in range(N):
            if cids[j] == i:
                npoints += 1
        if npoints < minpoints:
            #print('cluster %d has only %d points' % (i, npoints))
            # remove cluster i
            # shift all entries at i and above in scouts array down by one
            for scouti in range(i, M-1):
                for k in range(ndims):
                    scouts[scouti, k] = scouts[scouti+1, k]
                still[scouti] = still[scouti+1] # ditto for still array
            # update cluster indices
            for clustii in range(N):
                if cids[clustii] == i:
                    cids[clustii] = -1 # overwrite all occurences of i with -1
                elif cids[clustii] > i:
                    cids[clustii] -= 1 # decr all clust indices above i
            M -= 1 # decr num of scouts, don't inc i, new value at i has just slid into view
            npointsremoved += npoints
            nclustsremoved += 1
        else:
            i += 1
    print('%d points (%.1f%%) and %d clusters deleted for having less than %d points each' %
         (npointsremoved, npointsremoved/float(N)*100, nclustsremoved, minpoints))

    moving = still[:M] < maxstill
    nmoving = moving.sum()
    print('\nniters: %d' % iteri)
    print('nscouts: %d' % M)
    print('sigma: %.3f, rneigh: %.3f, rmerge: %.3f, alpha: %.3f' % (sigma, rneigh, rmerge, alpha))
    print('nmoving: %d, minmove: %f' % (nmoving, minmove))
    print('moving scouts: %r' % np.where(moving)[0])
    print('still array:')
    print still[:M]
    return cids, scouts[:M]


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cpdef move_scouts(int lo, int hi,
                  np.ndarray[np.float32_t, ndim=2, mode='c'] scouts,
                  np.ndarray[np.float32_t, ndim=2, mode='c'] data,
                  np.ndarray[np.uint8_t, ndim=1, mode='c'] still,
                  int N, int ndims, double sigma2, double alpha,
                  double rneigh, double rneigh2, double minmove2, int maxstill):
    """Move scouts up their local density gradient"""

    # use much faster C allocation for temporary 1D arrays instead of numpy:
    cdef double *ds = <double *>malloc(ndims*sizeof(double))
    cdef double *d2s = <double *>malloc(ndims*sizeof(double))
    cdef double *kernel = <double *>malloc(ndims*sizeof(double))
    cdef double *v = <double *>malloc(ndims*sizeof(double))

    cdef Py_ssize_t i, j, k
    #cdef int nneighs
    cdef bint continuej=False
    cdef double d2, kern, move, move2#, maxmove = 0.0
    with nogil:
        for i in range(lo, hi): # iterate over lo to hi scout points
            # skip frozen scout points
            if still[i] == maxstill:
                continue
            # measure gradient
            #nneighs = 0 # reset
            #for k in range(ndims):
            #    kernel[k] = 0.0 # reset
            #    v[k] = 0.0 # reset
            # slightly faster, though not guaranteed to be valid thing to do for non-int array:
            memset(kernel, 0, ndims*sizeof(double)) # reset
            memset(v, 0, ndims*sizeof(double)) # reset
            for j in range(N): # iterate over data, check if they're within rneigh
                d2 = 0.0 # reset
                for k in range(ndims): # iterate over dims for each point
                    ds[k] = data[j, k] - scouts[i, k]
                    if fabs(ds[k]) > rneigh: # break out of k loop, continue to next j loop
                        continuej = True
                        break # out of k loop
                    d2s[k] = ds[k] * ds[k] # used twice, so calc it only once
                    d2 += d2s[k]
                if continuej:
                    continuej = False # reset
                    continue # to next j
                if d2 <= rneigh2: # do the calculation
                    for k in range(ndims):
                        # v is ndim vector of sum of kernel-weighted distances between
                        # current scout point and all data within rneigh
                        #kern = exp(-d2s[k] / twosigma2) # Gaussian kernel
                        kern = sigma2 / (d2s[k] + sigma2) # Cauchy kernel, faster
                        #printf('%.3f ', kern)
                        kernel[k] += kern
                        v[k] += ds[k] * kern
                    #nneighs += 1
            # update scout position in direction of v, normalize by kernel
            # nneighs (and kernel?) will never be 0, because each scout point starts as a data point
            move2 = 0.0 # reset
            for k in range(ndims):
                move = alpha / kernel[k] * v[k] # normalize by kernel, not just nneighs
                scouts[i, k] += move
                move2 += move * move
                #if fabs(move) > fabs(maxmove):
                #    maxmove = move
            if move2 < minmove2:
                still[i] += 1 # count scout as still during this iter
            else:
                still[i] = 0 # reset stillness counter for this scout
        # wanted to see if points move faster when normalized by kernel vs nneighs:
        #printf('%f ', maxmove)

        free(ds)
        free(d2s)
        free(kernel)
        free(v)


#@cython.boundscheck(False)
#@cython.wraparound(False)
@cython.cdivision(True)
cdef void span(long *lohi, int start, int end, int N) nogil:
    """Fill len(N) lohi array with fairly equally spaced int
    values, from start to end"""
    cdef Py_ssize_t i
    cdef int step
    step = <int>ceil(<double>(end - start) / N) # round up
    for i in range(N):
        lohi[i] = start + step*i
    lohi[N] = end

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef long prod(np.ndarray[np.uint32_t, ndim=1, mode='c'] a) nogil:
    """Return product of entries in uint32 array a"""
    cdef long result, n
    cdef Py_ssize_t i
    n = a.shape[0] # this doesn't invoke Python apparently
    result = 1
    for i in range(n):
        result *= a[i]
    return result

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef long long ndi2li(np.ndarray[np.uint32_t, ndim=1, mode='c'] ndi,
                      np.ndarray[np.uint32_t, ndim=1, mode='c'] dims) nogil:
    """Convert n dimensional index in array ndi to linear index. ndi
    and dims should be the same length, and each entry in ndi should be
    less than its corresponding dimension size in dims"""
    cdef long long li, pr=1
    cdef Py_ssize_t di, ndims
    ndims = ndi.shape[0]
    li = ndi[ndims-1] # init with index of deepest dimension
    # iterate from ndims-1 to 0, from 2nd deepest to shallowest dimension
    # either syntax works, and both seem to be C optimized:
    #for di in range(ndims-1, 0, -1):
    for di from ndims-1 >= di > 0:
        pr *= dims[di] # running product of dimensions
        li += ndi[di-1] * pr # accum sum of products of next ndi and all deeper dimensions
    return li
