"""
compile using something like:
python setup.py build_ext --compiler=mingw32 --inplace
"""

#a = np.zeros((54,25000), dtype=int)

include "Python.pxi" # Includes from the python headers
include "numpy.pxi" # Include the Numpy C API for use via Cython extension code
import_array() # Initialize numpy - this MUST be done before any other code is executed.

cdef extern from "stdio.h":
    int printf(char *, ...)
    cdef void *malloc(int)

cdef extern from "string.h":
    cdef void *memcpy(void *, void *, int)


import numpy as np
import time

NAN = 0x7fffffff # one of the many possible hex values that code for single float IEEE standard 754 NaN (quiet NaN)


def cy_setmat(ndarray a, int val):
    """This is how to index into np arrays quickly,
    just as fast as weave.inline. Assumes 2D int array"""
    cdef int i, j
    cdef int *ap = <int *>a.data # int pointer to .data field
    cdef int nrows=a.dimensions[0]
    cdef int ncols=a.dimensions[1]
    for i from 0 <= i < nrows:
        for j from 0 <= j < ncols:
            ap[i*ncols+j] = val # a[i][j] also works, but is just as slow as a[i,j]

cpdef cy_recurse(int val):
    """Recursion works in Cython!"""
    if val > 0:
        val -= 1
        print 'recurse...'
        cy_recurse(val)
    print 'done'

cpdef cy_inc(int N=1000000000):
    """In place incrementation is just as fast as in weave.inline.
    With def: 2.1 sec, width cpdef: 1.4 sec. weave.inline is also 1.4 sec

    #timeit.Timer('cy_inc(1000000000)', 'from __main__ import cy_inc').timeit(1)
    """
    cdef int i=0
    while i < N:
        i += 1
    return i

cpdef point(ndarray a):
    """Print out all the values in a 1D array, index directly into
    array data quickly with a pointer of the right size"""
    cdef int *ap = <int *>a.data # int pointer to .data field
    cdef int n = a.dimensions[0]
    for i from 0 <= i < n:
        print ap[i]

cpdef longtest(long long v):
    """long long is int64, long seems to be just an int32"""
    print v

cpdef emptyloop():
    """Apparently, cycling through 1 sec of data only takes
    8.6e-08 sec, so that's definitely not a slow step for any detector algorithm

    #timeit.Timer('emptyloop', 'from __main__ import emptyloop').timeit(100)/100
    """
    cdef int i, j
    cdef int val=0
    for i from 0 <= i < 25000: # 1 sec of data
        for j from 0 <= j < 54: # all chans
            val += 1

cpdef strides(ndarray a):
    """Show how to deal with a 2D array whose last (1th) dimension
    has a -ve stride, ie an array that's just a view of some data
    with the last dimension reversed

    a = np.array(([100,200,300,400,500], [1,2,3,4,5]), dtype=np.int64)
    a[:,::-1]
    a[:,::-2]

    """
    cdef long long *datap = <long long *>a.data
    cdef int nchans = a.dimensions[0]
    cdef int nt = a.dimensions[1]
    print 'address of datap:', <int>datap # this changes depending on how a is sliced relative to its original data
    print 'strides:', a.strides[0], a.strides[1]
    print 'sizeof long long:', sizeof(long long)
    cdef int dchan = a.strides[0] / <int>sizeof(long long) # how many items you need to skip over to get from one chan to next, this will normally be nt, unless you've sliced the 0th (chan) axis somehow
    cdef int dt = a.strides[1] / <int>sizeof(long long) # +/- 1 depending on whether it's sliced normally or in reverse order - how many items to skip over to get from one timepoint to the next
    print 'dchan, dt:', dchan, dt
    assert dchan == nt
    assert abs(dt) == 1
    cdef int ti, chani
    for ti from 0 <= ti < nt:
        for chani from 0 <= chani < nchans:
            print datap[chani*nt + ti*dt]

cpdef swap(int i, int j):
    """Show that you can use Python tuple notation to swap two C types"""
    i, j = j, i
    print 'i: %d, j: %d' % (i, j)


cdef struct Settings:
    int maxchanii
    int *chansp
    int nchans
    int ndmchans
    double *dmp
    double slock
    int tilock
    float *datap
    float *absdatap
    long long *tsp
    int *xthreshp
    float *lastp
    int *lockp
    int nt
    int ti

cdef Settings s

cdef modstruct(Settings *s, int chanii): # can't be a cpdef
    s.maxchanii = chanii

print s.maxchanii
s.maxchanii = 1
print s.maxchanii
modstruct(&s, 53) # pass by reference
print s.maxchanii
'''
cdef struct Spam:
    int tons

cdef void myfun(Spam *s): # not sure if void is necessary...
    s.tons = 20

cdef Spam myspam
myspam.tons = 10

print myspam.tons
myfun(&myspam)
print myspam.tons
'''
cdef int max(int x, int y):
    """Return maximum of two ints"""
    if x >= y:
        return x
    else:
        return y

print 'max(1,1):', max(1,1)
print 'max(1,2):', max(1,2)
print 'max(2,1):', max(2, 1)
print 'max(-1,0):', max(-1, 0)


cdef int min(int x, int y):
    """Return minimum of two ints"""
    if x <= y:
        return x
    else:
        return y

print 'min(1,1):', min(1,1)
print 'min(1,2):', min(1,2)
print 'min(2,1):', min(2, 1)
print 'min(-1,0):', min(-1, 0)

cdef int iabs(int x):
    """Absolute value of an integer"""
    if x < 0:
        x *= -1
    return x

print 'iabs(-5):', iabs(-5)
print 'iabs(5):', iabs(5)


cdef float abs(float x):
    """Absolute value of a float"""
    if x < 0.0:
        x *= -1.0
    return x

print 'abs(-5):', abs(-5)
print 'abs(5):', abs(5)
print 'abs(-5.0):', abs(-5.0)
print 'abs(5.0):', abs(5.0)


cdef faabs(float *a, long long length):
    """In-place abs of a float array of given length"""
    cdef long long i
    for i from 0 <= i < length:
        if a[i] < 0.0:
            a[i] *= -1.0 # modify in-place

cdef ndarray data = np.array([-3., -10, 10, 3, 3.], dtype=np.float32)
cdef float *datap = <float *>data.data # float pointer to data's .data field
for i in range(5):
    print datap[i]
faabs(datap, 5)
for i in range(5):
    print datap[i]


cdef float select(float *a, int l, int r, int k):
    """Returns the k'th (0-based) ranked entry from float array a within left
    and right pointers l and r. This is quicksort partitioning based
    selection, taken from Sedgewick (Algorithms, 2ed 1988, p128).
    Note that this modifies a in-place"""
    cdef int i, j
    cdef float v, temp
    if r < l:
        raise ValueError, 'bad pointer range in select()'
    while r > l:
        v = a[r]
        i = l-1
        j = r
        while True:
            while True:
                i += 1
                if a[i] >= v: break
            while True:
                j -= 1
                if a[j] <= v: break
            temp = a[i] # swap a[i] and a[j]
            a[i] = a[j]
            a[j] = temp
            if j <= i: break
        a[j] = a[i]
        a[i] = a[r]
        a[r] = temp # temp was old a[j]
        if i >= k: r = i-1
        if i <= k: l = i+1
    return a[k] # return kth in 0-based


def selectpy(ndarray data, int k):
    """Test Cython select() from Python

    data = np.float32(np.random.rand(10000000))
    data = np.array([1., 2., 2., 3., 1., 3., 5.], dtype=np.float32)
    """
    cdef int N = len(data)
    print data
    tpy = time.time()
    sorteddata = np.sort(data) # do a full quicksort
    print 'Python:', sorteddata[k]
    print 'Python took %.3f sec' % (time.time()-tpy)
    cdef float *a = <float *>data.data # float pointer to data's .data field
    tcy = time.time()
    print 'Cython:', select(a, 0, N-1, k)
    print 'Cython took %.3f sec' % (time.time()-tcy)
    print sorteddata


def copy_test():
    cdef float *a
    cdef int i, length = 10
    cdef ndarray data = np.arange(length, dtype=np.float32)
    print data
    print data.dtype
    cdef float *datap = <float *>data.data # float pointer to data's .data field
    #cdef char *datap = 'testing'
    #length = len(datap)
    for i in range(length):
        print datap[i]
    a = <float *>malloc(length*sizeof(float))
    a = <float *>memcpy(a, datap+5, (length-5)*sizeof(float))
    for i in range(length-5):
        print a[i]
    print 'sizeof(float) is', sizeof(float)
    a = <float *>memcpy(a, datap+2, (length-2)*sizeof(float))
    for i in range(length-2):
        print a[i]
    print 'sizeof(float) is', sizeof(float)

