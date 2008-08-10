"""Event detection loops implemented in Cython for speed"""

from __future__ import division

__author__ = 'Martin Spacek'

cdef extern from "stdio.h":
    int printf(char *, ...)

cdef extern from "stdlib.h":
    cdef void *malloc(int)

cdef extern from "string.h":
    cdef void *memcpy(void *, void *, int)


include "Python.pxi" # include from the python headers
include "numpy.pxi" # include the Numpy C API for use via Cython extension code
import_array() # initialize numpy - this MUST be done before any other code is executed.

#import sys
import time
import numpy as np

from spyke.core import intround

#DEF INF = float('+inf') # doesn't work on Windows until Python 2.6+
DEF INF = float(2**128)
#DEF MAXINT = int(sys.maxint) # declare it here to prevent Python name lookups, doesn't work
#DEF MAXINT = int(2**31-1)
DEF DEFTIRANGE = 1000 # more reasonable to use this than MAXINT, won't overflow when added to an int32

# struct of relevant detector vars that need to be passed around to functions
cdef struct Settings:
    int maxchanii
    int *chansp
    int nchans
    double *dmp
    int ndmchans
    double slock
    int tilock
    float *datap
    float *threshp
    int threshmethod # see STRTHRESH2ID
    int noisemethod # see STRNOISE2ID
    float noisemult
    long long *tsp
    int *lockp
    int nt # number of timepoints in data
    int nnt # number of noise timepoints to consider when calculating thresholds

STRTHRESH2ID = {'GlobalFixed': 0, 'ChanFixed': 1, 'Dynamic': 2}
STRNOISE2ID = {'median': 0, 'stdev': 1}


cpdef class BipolarAmplitude_Cy:

    cpdef searchblock(self, wave, cutrange, int maxnevents):
        """Search one timepoint at a time across chans in a manageable
        block of waveform data and return a 2D array of event times and maxchans.
        Apply both temporal and spatial lockouts.
        cutrange: determines which events are saved and which are discarded as excess
        maxnevents: maximum number of events to return while searching this block

        TODO: instead of searching forward indefinitely for a peak, maybe search
              forward and backwards say 0.5ms. Ah, but then searching backwards would
              ignore any tlock you may have had on that chan in the past. Maybe that means
              having to change how tlock is implemented

        TODO: (maybe): chanii loop should go in random order on each ti, to prevent a chan from
              dominating with its spatial lockout or something like that. So, shuffle chans in-place
              on every ti, or have a second level of chan indices, shuffle those every ti, and iterate over chaniii
        """
        cdef Settings s # has to be passed by reference

        if not wave.data.flags.contiguous:
            #print "wave.data ain't contig, strides:", wave.data.strides
            wave.data = wave.data.copy() # make it contiguous for easy pointer indexing
        if not wave.ts.flags.contiguous:
            #print "wave.ts ain't contig, strides:", wave.ts.strides
            wave.ts = wave.ts.copy()

        s.nchans = len(self.chans)
        cdef ndarray chans = np.asarray(self.chans)
        s.chansp = <int *>chans.data # int pointer to .data field

        if self.chans != range(s.nchans): # if self.chans is not contiguous
            #ttake = time.clock()
            # pull our chans of data out, this assumes wave.data has all possible chans in it, which it should
            contigdata = wave.data.take(chans, axis=0) # returns a contiguous copy of data
            #print 'data take in searchblock() took %.3f sec' % (time.clock()-ttake)
        else: # save time by avoiding an unnecessary .take
            contigdata = wave.data
        cdef ndarray data = contigdata
        s.datap = <float *>data.data # float pointer to data's .data field, rows correspond to chans in chansp

        cdef ndarray ts = wave.ts
        s.tsp = <long long *>ts.data # long long pointer to timestamp .data
        cdef long long eventt # holds current event timestamp

        assert s.nchans == data.dimensions[0] # yup
        s.nt = data.dimensions[1]
        cdef ndarray thresh = np.asarray(self.thresh)
        s.threshp = <float *>thresh.data # float pointer to thresh .data

        # cut times, these are for testing whether to inc nevents
        cdef long long cut0 = cutrange[0]
        cdef long long cut1 = cutrange[1]
        if cut0 > cut1: # swap 'em for the test
            cut0, cut1 = cut1, cut0

        cdef ndarray lock = np.zeros(s.nchans, dtype=int) # per-channel lockout timepoint indices (end inclusive?)
        s.lockp = <int *>lock.data # int pointer to .data field

        s.tilock = self.tilock # temporal index lockout, in num timepoints
        s.slock = self.slock # spatial lockout, in um
        cdef ndarray dm = self.dm # full Euclidean channel distance matrix for all possible chanis, floats in um
        s.dmp = <double *>dm.data # double pointer to .data field
        s.ndmchans = len(self.dm) # number of all possible chans in dm

        cdef ndarray eventtimes = self._eventtimes # init'd in self.search()
        cdef long long *eventtimesp = <long long *>eventtimes.data # long long pointer to .data field
        cdef ndarray maxchans = self._maxchans # init'd in self.search()
        cdef int *maxchansp = <int *>maxchans.data # int pointer to .data field

        cdef int ti, prevti, chanii, peakti, lastpeakti
        cdef float sign
        cdef int nevents = 0 # num non-excess events found so far while searching this block
        cdef int eventi = -1 # event index (indexes into .eventtimes)
        cdef int eventti # event time index (indexes into .data and .ts)

        #tcyloop = time.clock()
        for ti from 0 <= ti < s.nt: # iterate over all timepoint indices
            prevti = max(ti-1, 0) # previous timepoint index, ensuring to go no earlier than first timepoint
            # TODO: shuffle chans in-place here
            for chanii from 0 <= chanii < s.nchans: # iterate over indices into chans
                # check that chan is free at previous timepoint and that we've gone from below to at or above threshold
                if not ( s.lockp[chanii] < prevti and abs(s.datap[chanii*s.nt + prevti]) < s.threshp[chanii] \
                         and abs(s.datap[chanii*s.nt + ti]) >= s.threshp[chanii] ):
                    continue # no, skip to next chan in chan loop
                sign = get_sign(s.datap[chanii*s.nt + ti]) # find whether thresh xing was +ve or -ve
                # find maxchan at timepoint ti by searching across eligible chans, center search on chanii
                find_maxchanii(&s, chanii, ti, sign)
                # search forward indefinitely for the first peak, this will be used as the event time
                eventti = find_peak(&s, ti, DEFTIRANGE, sign) # search forward almost indefinitely for peak of correct phase
                if eventti == -1: # couldn't find a peak
                    continue # skip to next chan in chan loop
                # if we get this far, it's a valid event
                find_maxchanii(&s, s.maxchanii, eventti, sign) # update maxchan one last time for this event
                eventti = find_peak(&s, eventti, s.tilock, sign) # update eventti for this maxchan
                eventt = s.tsp[eventti] # event time
                #print 'ti=%s, t=%s, chanii=%s, sign=%d, eventt=%s, maxchanii=%s' % (ti, s.tsp[ti], chanii, sign, eventt, s.maxchanii)
                if cut0 <= eventt and eventt <= cut1: # event falls within cutrange, save it
                    eventi += 1
                    eventtimesp[eventi] = eventt # save event time
                    maxchansp[eventi] = s.chansp[s.maxchanii] # save maxchani that event is centered on
                    nevents += 1 # this event has been saved, so inc
                if nevents >= maxnevents: # exit here, don't search any more chans
                    ti = s.nt # TODO: nasty hack to get out of outer ti loop
                    break # out of inner chanii loop
                # to set lockout, continue searching forward for consecutive threshold-exceeding peaks
                # of alternating phase within tlock of each other that are conceivably
                # part of the same spike, yet large enough and far enough away in time to trigger an
                # unwanted threshold crossing
                # ch31 t=40880 is a corner case where this fails badly, can probably only be fixed by using multiphasic detection
                # ch46 t=68420 is another tough case centered on a smaller chan with a premature peak due to distorted signal
                lastpeakti = eventti
                while True:
                    sign = -sign
                    peakti = find_peak(&s, lastpeakti, s.tilock, sign)
                    if peakti == -1 or abs(s.datap[s.maxchanii*s.nt + peakti]) < s.threshp[s.maxchanii]:
                        # no peak found, or found peak doesn't meet or exceed thresh
                        break # out of while loop
                    lastpeakti = peakti # update
                set_lockout(&s, lastpeakti+s.tilock) # lock out up to peak of last spike phase plus another tlock
        #print 'cy loop took %.3f sec' % (time.clock()-tcyloop)
        eventtimes = eventtimes[:nevents] # keep only the entries that were filled
        maxchans = maxchans[:nevents] # keep only the entries that were filled
        return np.asarray([eventtimes, maxchans])


cpdef class DynamicMultiphasic_Cy:

    cpdef searchblock(self, wave, cutrange, int maxnevents):
        """Search one timepoint at a time across chans in a manageable
        block of waveform data and return a 2D array of event times and maxchans.
        Apply both temporal and spatial lockouts.
        cutrange: determines which events are saved and which are discarded as excess
        maxnevents: maximum number of events to return while searching this block
        """
        cdef Settings s # has to be passed by reference

        if not wave.data.flags.contiguous:
            #print "wave.data ain't contig, strides:", wave.data.strides
            wave.data = wave.data.copy() # make it contiguous for easy pointer indexing
        if not wave.ts.flags.contiguous:
            #print "wave.ts ain't contig, strides:", wave.ts.strides
            wave.ts = wave.ts.copy()

        s.nchans = len(self.chans)
        cdef ndarray chans = np.asarray(self.chans)
        s.chansp = <int *>chans.data # int pointer to .data field

        if self.chans != range(s.nchans): # if self.chans is not contiguous
            #ttake = time.clock()
            # pull our chans of data out, this assumes wave.data has all possible chans in it, which it should
            contigdata = wave.data.take(chans, axis=0) # returns a contiguous copy of data
            #print 'data take in searchblock() took %.3f sec' % (time.clock()-ttake)
        else: # save time by avoiding an unnecessary .take
            contigdata = wave.data
        cdef ndarray data = contigdata
        s.datap = <float *>data.data # float pointer to data's .data field, rows correspond to chans in chansp

        cdef ndarray ts = wave.ts
        s.tsp = <long long *>ts.data # long long pointer to timestamp .data
        cdef long long eventt # holds current event timestamp

        assert s.nchans == data.dimensions[0] # yup
        s.nt = data.dimensions[1]
        s.threshmethod = STRTHRESH2ID[self.threshmethod] # ID
        # number of noise timepoints to consider for dynamic thresh
        s.nnt = intround(self.dynamicnoisewin / 1000000 * self.stream.sampfreq )
        s.noisemult = self.noisemult
        cdef ndarray thresh = np.asarray(self.thresh)
        s.threshp = <float *>thresh.data # float pointer to thresh .data

        # cut times, these are for testing whether to inc nevents
        cdef long long cut0 = cutrange[0]
        cdef long long cut1 = cutrange[1]
        if cut0 > cut1: # swap 'em for the test
            cut0, cut1 = cut1, cut0

        cdef ndarray lock = np.zeros(s.nchans, dtype=int) # per-channel lockout timepoint indices (end inclusive?)
        s.lockp = <int *>lock.data # int pointer to .data field

        s.tilock = self.tilock # temporal index lockout, in num timepoints
        s.slock = self.slock # spatial lockout, in um
        cdef ndarray dm = self.dm # full Euclidean channel distance matrix for all possible chanis, floats in um
        s.dmp = <double *>dm.data # double pointer to .data field
        s.ndmchans = len(self.dm) # number of all possible chans in dm

        cdef ndarray eventtimes = self._eventtimes # init'd in self.search()
        cdef long long *eventtimesp = <long long *>eventtimes.data # long long pointer to .data field
        cdef ndarray maxchans = self._maxchans # init'd in self.search()
        cdef int *maxchansp = <int *>maxchans.data # int pointer to .data field

        cdef int ti, prevti, chanii, prepeakti, postpeakti, peak2ti, peakti, lastpeakti
        cdef float sign
        cdef int nevents = 0 # num non-excess events found so far while searching this block
        cdef int eventi = -1 # event index (indexes into .eventtimes)
        cdef int eventti # event time index (indexes into .data and .ts)

        '''procedure according to paper (indented stuff are my additions/speculations):
            - for all methods, get thresh xing, make sure it's a +ve thresh xing from low abs(signal)
              to high abs(signal), ie make sure the signal at the preceding timepoint isn't locked out
              and is below threshold
                - center on non locked-out maxchan within slock of chan with thresh xing?
            - search forward indefinitely (?) to find waveform peak/valley - this is your spike time?
                - again, center on non locked-out maxchan within slock of chan with thresh xing?
                - again, search forward a bit to ensure you're at the waveform peak/valley - this is your spike time
            - search forward and back by one tlock relative to timepoint of thresh xing
                - or should this search be relative to time of the peak/valley? This seems much better
            - within that search, look for signal 2f greater than valley/2f less than peak
                - if you find such signal, you've got a spike
                - respect previously set lockouts during this search? maybe yes, or maybe lockouts should just be considered when looking for threshold xings. Maybe yes though, cuz otherwise one spike's phase might incorrectly be considered to be the phase of another, ie it might get duplicate treatment
                - this seems to prevent detection of uniphase spikes - maybe if the above search fails, search forward 1/2 a tlock for a return of the signal to 0?
                    - actually, this may be solved by going to dynamic median based thresholds, separate for each chan
                - seem to require a tlock > 250us, say 300us, to search far enough for the next phase of the putative spike, for exceptionally fat spikes, like ch26 t=14720

            - general lockout procedure (applies to all): only those chans within slock of maxchan that are over
              threshold at spike time are locked out, and are locked out only until the end of the first half of the
              first phase of the spike, although I'm not too clear why. Why not until the end of the first half of
              the last phase of the spike?
                - I'm going to end of first half of last phase of the spike, but this sometimes causes double triggers of the same spike (which is dangerous, false +ves and worse than false -ves) due to surrounding channels sometimes being distorted and peaking slightly later than the maxchan, so perhaps I should lockout for at least s.tilock relative to eventti, ie for max(lastpeakti, eventti+s.tilock)

        '''
        #tcyloop = time.clock()
        for ti from 0 <= ti < s.nt: # iterate over all timepoint indices
            prevti = max(ti-1, 0) # previous timepoint index, ensuring to go no earlier than first timepoint
            if s.threshmethod == 2 and ti % s.nnt == 0: # update dynamic channel thresholds every nnt'th timepoint
                set_thresh(&s, ti)
            # TODO: shuffle chans in-place here
            for chanii from 0 <= chanii < s.nchans: # iterate over indices into chans
                # check that chan is free at previous timepoint and that we've gone from below to at or above threshold
                if not ( s.lockp[chanii] < prevti and abs(s.datap[chanii*s.nt + prevti]) < s.threshp[chanii] \
                         and abs(s.datap[chanii*s.nt + ti]) >= s.threshp[chanii] ):
                    continue # no, skip to next chan in chan loop
                sign = get_sign(s.datap[chanii*s.nt + ti]) # find whether thresh xing was +ve or -ve
                # find maxchan at timepoint ti by searching across eligible chans, center search on chanii
                find_maxchanii(&s, chanii, ti, sign)
                # search forward indefinitely for the first peak, this will be used as the event time
                eventti = find_peak(&s, ti, DEFTIRANGE, sign) # search forward almost indefinitely for peak of correct phase
                if eventti == -1: # couldn't find a peak
                    #print 'couldnt find any peak at all'
                    continue # skip to next chan in chan loop
                find_maxchanii(&s, s.maxchanii, eventti, sign) # update maxchan one last time for this putative event
                eventti = find_peak(&s, eventti, s.tilock, sign) # update eventti for this maxchan
                #print 'ti=%s, t=%s, chanii=%s, sign=%d, eventt=%s, maxchanii=%s' % (ti, s.tsp[ti], chanii, sign, s.tsp[eventti], s.maxchanii)
                # search forward and backward one tlock on the maxchan for another peak of opposite phase
                # that is 2*thresh greater (in the right direction) than the event peak
                sign = -sign
                prepeakti = find_peak(&s, eventti, -s.tilock, sign)
                postpeakti = find_peak(&s, eventti, s.tilock, sign)
                if prepeakti != -1 and postpeakti != -1: # both exist, need to find the biggest one relative to event
                    if s.datap[s.maxchanii*s.nt + prepeakti] * sign > s.datap[s.maxchanii*s.nt + postpeakti] * sign:
                        peak2ti = prepeakti
                    else:
                        peak2ti = postpeakti
                elif prepeakti != -1 and postpeakti == -1:
                    peak2ti = prepeakti
                elif prepeakti == -1 and postpeakti != -1:
                    peak2ti = postpeakti
                else:
                    #print 'couldnt find a pre or post event peak'
                    continue # skip to next chan in chan loop
                #print 'eventt=%s, peak2t=%s, sign=%s' % (s.tsp[eventti], s.tsp[peak2ti], sign)
                if abs(s.datap[s.maxchanii*s.nt + eventti] - s.datap[s.maxchanii*s.nt + peak2ti]) < 2*s.threshp[s.maxchanii]:
                    #print 'peak2 isnt big enough'
                    continue # skip to next chan in chan loop
                # if we get this far, it's a valid event
                #print 'FOUND A SPIKE!!!!!!!!!!!!!!!!!!'
                eventt = s.tsp[eventti] # event time
                if cut0 <= eventt and eventt <= cut1: # event falls within cutrange, save it
                    eventi += 1
                    eventtimesp[eventi] = eventt # save event time
                    maxchansp[eventi] = s.chansp[s.maxchanii] # save maxchani that event is centered on
                    nevents += 1 # this event has been saved, so inc
                if nevents >= maxnevents: # exit here, don't search any more chans
                    ti = s.nt # TODO: nasty hack to get out of outer ti loop
                    break # out of inner chanii loop
                # to set lockout, continue searching forward for consecutive threshold-exceeding
                # peaks of alternating phase within tlock of each other that are conceivably
                # part of the same spike, yet large enough and far enough away in time to trigger an
                # unwanted threshold crossing
                lastpeakti = max(eventti, peak2ti)
                #print 'lastpeakt=%s' % s.tsp[lastpeakti]
                while True:
                    sign = -sign
                    peakti = find_peak(&s, lastpeakti, s.tilock, sign)
                    if peakti == -1 or abs(s.datap[s.maxchanii*s.nt + peakti]) < s.threshp[s.maxchanii]:
                        # no peak found, or found peak doesn't exceed thresh
                        break # out of while loop
                    #print 'found new lockout peakt=%s, sign=%s' % (s.tsp[peakti], sign)
                    lastpeakti = peakti # update
                #print 'lockout to lastpeakt=%s' % s.tsp[lastpeakti]
                set_lockout(&s, lastpeakti) # lock out up to and including peak of last spike phase, and no further
        #print 'cy loop took %.3f sec' % (time.clock()-tcyloop)
        eventtimes = eventtimes[:nevents] # keep only the entries that were filled
        maxchans = maxchans[:nevents] # keep only the entries that were filled
        return np.asarray([eventtimes, maxchans])

cdef set_thresh(Settings *s, int ti):
    """Sets channel specific threshold (either median or stdev-based)
    based on the last available s.nnt datapoints leading up to ti
    (and possibly including it, if we're near the beginning of the block we're
    currently searching)"""
    cdef int chanii

    cdef long long l, offset, startti = max(ti - s.nnt, 0) # bounds checking
    cdef long long endti = min(startti + s.nnt, s.nt-1)
    cdef long long nnt = endti - startti + 1 # may differ from s.nnt depending on whether we're near limits of recording
    cdef float noise
    cdef float *data
    for chanii from 0 <= chanii < s.nchans: # iterate over all chan indices
        offset = chanii*s.nt
        l = offset + startti # left offset
        #r = offset + endti # right offset
        if s.noisemethod == 0: # median
            # create a copy, to prevent modification of the original
            data = <float *>malloc(nnt*sizeof(float))
            data = <float *>memcpy(data, s.datap+l, nnt) # copy nnt points starting from datap offset l
            faabs(data, nnt) # do in-place abs
            noise = median(data, 0, nnt-1) / 0.6745 # see Quiroga, 2004
        elif s.noisemethod == 1: # stdev
            #return np.stdev(data, axis=-1)
            raise NotImplementedError
        else:
            raise ValueError
        s.threshp[chanii] = noise * s.noisemult

cdef float median(float *a, int l, int r):
    """Select the median value in a, between l and r pointers"""
    return select(a, l, r, (r-l) // 2)

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

cdef find_maxchanii(Settings *s, int maxchanii, int ti, float sign):
    """Update s.maxchanii at timepoint ti over non locked-out chans within slock of maxchanii.
    Finds most negative (sign == -1) or most positive (sign == 1) chan"""
    cdef int chanjj, chanj, maxchani
    cdef int prevti = max(ti-1, 0) # previous timepoint, ensuring to go no earlier than first timepoint
    s.maxchanii = maxchanii # init
    maxchani = s.chansp[maxchanii] # dereference to index into dmp
    for chanjj from 0 <= chanjj < s.nchans: # iterate over all chan indices
        chanj = s.chansp[chanjj] # dereference to index into dmp
        # if chanj is within slock of original maxchani, and has higher signal of correct sign than the biggest maxchan found so far, and has the slope of the same sign wrt previous timepoint, and isn't locked out:
        if s.dmp[maxchani*s.ndmchans + chanj] <= s.slock and \
            s.datap[chanjj*s.nt + ti]*sign > s.datap[s.maxchanii*s.nt + ti]*sign and \
            s.datap[chanjj*s.nt + ti]*sign > s.datap[chanjj*s.nt + prevti]*sign and \
            s.lockp[chanjj] < ti:
            s.maxchanii = chanjj # update

cdef float get_sign(float val):
    """Return the sign of the float input"""
    if val < 0.0:
        return -1.0
    else:
        return 1.0

cdef int find_peak(Settings *s, int ti, int tirange, float sign):
    """Return timepoint index of first peak (if sign == 1) or valley (if sign == -1)
    on s.maxchanii searching forward up to tirange from passed ti. Searches backwards
    if tirange is -ve.
    Return -1 if no peak is found

    TODO: perhaps find_peak should ensure the maxchanii isn't locked out over any of
    the tirange it's searching, although this is implicit when it's called, ie,
    don't call find_peak without first checking for lockout up to ti

    NOTE: this only finds the first peak, not the biggest peak within tirange
          but perhaps it should stay this way
    """
    cdef int end, tj, peaktj = -1
    cdef long long offset = s.maxchanii*s.nt # this stays constant
    cdef float last = -INF * sign # uV
    if tirange >= 0:
        end = min(ti+tirange, s.nt) # prevent exceeding max t index in data
        for tj from ti <= tj < end:
            # if signal is becoming more -ve (sign == -1) or +ve (sign == 1)
            if s.datap[offset + tj]*sign > last*sign:
                peaktj = tj # update
                last = s.datap[offset + tj] # update
            else: # signal is becoming less -ve (sign == -1) or +ve (sign == 1)
                return peaktj
    else: # tirange is -ve
        end = max(ti+tirange, 0) # prevent exceeding min t index in data
        for tj from ti >= tj > end:
            # if signal is becoming more -ve (sign == -1) or +ve (sign == 1)
            if s.datap[offset + tj]*sign > last*sign:
                peaktj = tj # update
                last = s.datap[offset + tj] # update
            else: # signal is becoming less -ve (sign == -1) or +ve (sign == 1)
                return peaktj
    return -1 # a peak was never found

cdef set_lockout(Settings *s, int ti):
    """Apply spatiotemporal lockout centered on s.maxchanii, lock out all chans
    within slock up to timepoint ti"""
    cdef int chanjj, chanj, maxchani
    for chanjj from 0 <= chanjj < s.nchans: # iterate over all chan indices
        maxchani = s.chansp[s.maxchanii] # dereference to index into dmp
        chanj = s.chansp[chanjj] # dereference to index into dmp
        if s.dmp[maxchani*s.ndmchans + chanj] <= s.slock: # chanjj is within spatial lockout in um
            s.lockp[chanjj] = ti # lock it out up to ti

cdef int max(int x, int y):
    """Return maximum of two ints"""
    if x >= y:
        return x
    else:
        return y

cdef int min(int x, int y):
    """Return minimum of two ints"""
    if x <= y:
        return x
    else:
        return y

cdef float abs(float x):
    """Absolute value of a float"""
    if x < 0.0:
        x *= -1.0
    return x

cdef faabs(float *a, long long length):
    """In-place abs of a float array of given length"""
    cdef long long i
    for i from 0 <= i < length:
        if a[i] < 0.0:
            a[i] *= -1.0 # modify in-place

'''
cdef int iabs(int x):
    """Absolute value of an integer"""
    if x < 0:
        x *= -1
    return x

cdef arrabs(ndarray a):
    """In-place absolute value of 2D float32 array.
    Or, might be better to just use fabs from C math library?"""
    cdef int nrows = a.dimensions[0]
    cdef int ncols = a.dimensions[1]
    cdef float *datap = <float *>a.data
    cdef int i, j
    for i from 0 <= i < nrows:
        for j from 0 <= j < ncols:
            if datap[i*ncols + j] < 0.0:
                datap[i*ncols + j] *= -1.0 # modify in-place
'''
