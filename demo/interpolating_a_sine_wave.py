s = sin(np.arange(0, 2*np.pi, np.pi/8))
>>> s
array([ 0.        ,  0.38268343,  0.70710678,  0.92387953,  1.        ,  0.92387953,  0.70710678,  0.38268343,  0.        , -0.38268343, -0.70710678,
       -0.92387953, -1.        , -0.92387953, -0.70710678, -0.38268343])
>>> len(s)
16
>>> figure()
<matplotlib.figure.Figure object at 0x04002390>
>>> plot(s)
[<matplotlib.lines.Line2D object at 0x0425C0F0>]
>>> np.convolve(s, hamming(t, 12)*h(t), mode='same')
array([ 0.        ,  0.38268343,  0.70710678,  0.92387953,  1.        ,  0.92387953,  0.70710678,  0.38268343,  0.        , -0.38268343, -0.70710678,
       -0.92387953, -1.        , -0.92387953, -0.70710678, -0.38268343])
>>> len(np.convolve(s, hamming(t, 12)*h(t), mode='same'))
16
>>> plot(np.convolve(s, hamming(t, 12)*h(t), mode='same'))
[<matplotlib.lines.Line2D object at 0x04292BD0>]
>>> t = np.arange(start=-12/2-0.5-0, stop=-12/2-0.5+13-0, step=1)
>>> t
array([-6.5, -5.5, -4.5, -3.5, -2.5, -1.5, -0.5,  0.5,  1.5,  2.5,  3.5,  4.5,  5.5])
>>> plot(np.convolve(s, hamming(t, 12)*h(t), mode='same'))
[<matplotlib.lines.Line2D object at 0x0424A070>]
>>> z05 = np.convolve(s, hamming(t, 12)*h(t), mode='same')
>>> z05
array([-0.03291317,  0.161123  ,  0.57043491,  0.82263655,  0.98171161,  0.97667972,  0.82876982,  0.55256827,  0.19224321, -0.19734913, -0.55689686,
       -0.83345506, -0.98100832, -0.98502457, -0.82442951, -0.57043491])
>>> t = np.arange(start=-12/2-0-0, stop=-12/2-0+13-0, step=1)
>>> z0 = np.convolve(s, hamming(t, 12)*h(t), mode='same')
>>> figure()
<matplotlib.figure.Figure object at 0x04018E10>
>>> plot(s)
[<matplotlib.lines.Line2D object at 0x03F8FDD0>]
>>> plot(z0)
[<matplotlib.lines.Line2D object at 0x04018D70>]
>>> plot(z05)
[<matplotlib.lines.Line2D object at 0x04271810>]
>>> z[0::2]
Traceback (most recent call last):
  File "<input>", line 1, in <module>
NameError: name 'z' is not defined
>>> 16 + 15
31
>>> z = np.zeros(16+15)
>>> z
array([ 0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,
        0.,  0.,  0.])
>>> z[0::2] = z0
>>> z
array([ 0.        ,  0.        ,  0.38268343,  0.        ,  0.70710678,  0.        ,  0.92387953,  0.        ,  1.        ,  0.        ,  0.92387953,
        0.        ,  0.70710678,  0.        ,  0.38268343,  0.        ,  0.        ,  0.        , -0.38268343,  0.        , -0.70710678,  0.        ,
       -0.92387953,  0.        , -1.        ,  0.        , -0.92387953,  0.        , -0.70710678,  0.        , -0.38268343])
>>> z[1::2] = z05
Traceback (most recent call last):
  File "<input>", line 1, in <module>
ValueError: shape mismatch: objects cannot be broadcast to a single shape
>>> z[1::2] = z05[1:]
>>> z
array([ 0.        ,  0.161123  ,  0.38268343,  0.57043491,  0.70710678,  0.82263655,  0.92387953,  0.98171161,  1.        ,  0.97667972,  0.92387953,
        0.82876982,  0.70710678,  0.55256827,  0.38268343,  0.19224321,  0.        , -0.19734913, -0.38268343, -0.55689686, -0.70710678, -0.83345506,
       -0.92387953, -0.98100832, -1.        , -0.98502457, -0.92387953, -0.82442951, -0.70710678, -0.57043491, -0.38268343])
>>> plot(z)
[<matplotlib.lines.Line2D object at 0x04018310>]
>>> figure()
<matplotlib.figure.Figure object at 0x042713F0>
>>> plot(z)
[<matplotlib.lines.Line2D object at 0x03FA3470>]
>>> t = np.arange(start=-12/2-0.25-0, stop=-12/2-0.25+13-0, step=1)
>>> z025 = np.convolve(s, hamming(t, 12)*h(t), mode='same')
>>> plot(z025)
[<matplotlib.lines.Line2D object at 0x04250730>]
>>> z = np.zeros(16+15+15)
>>> z = np.zeros(16+15+15)
>>> t = np.arange(start=-12/2-0.75-0, stop=-12/2-0.75+13-0, step=1)
>>> z075 = np.convolve(s, hamming(t, 12)*h(t), mode='same')
>>> plot(z075)
[<matplotlib.lines.Line2D object at 0x042502B0>]
>>> z = np.zeros(16+15+15+15)
>>> z[0::2] = z0
Traceback (most recent call last):
  File "<input>", line 1, in <module>
ValueError: shape mismatch: objects cannot be broadcast to a single shape
>>> z[0::4] = z0
>>> z
array([ 0.        ,  0.        ,  0.        ,  0.        ,  0.38268343,  0.        ,  0.        ,  0.        ,  0.70710678,  0.        ,  0.        ,
        0.        ,  0.92387953,  0.        ,  0.        ,  0.        ,  1.        ,  0.        ,  0.        ,  0.        ,  0.92387953,  0.        ,
        0.        ,  0.        ,  0.70710678,  0.        ,  0.        ,  0.        ,  0.38268343,  0.        ,  0.        ,  0.        ,  0.        ,
        0.        ,  0.        ,  0.        , -0.38268343,  0.        ,  0.        ,  0.        , -0.70710678,  0.        ,  0.        ,  0.        ,
       -0.92387953,  0.        ,  0.        ,  0.        , -1.        ,  0.        ,  0.        ,  0.        , -0.92387953,  0.        ,  0.        ,
        0.        , -0.70710678,  0.        ,  0.        ,  0.        , -0.38268343])
>>> z[1::4] = z075[1:]
>>> z[2::4] = z05[1:]
>>> z[3::4] = z025[1:]
>>> z
array([ 0.        ,  0.06658149,  0.161123  ,  0.27128602,  0.38268343,  0.4840523 ,  0.57043491,  0.64316283,  0.70710678,  0.76547346,  0.82263655,
        0.8767625 ,  0.92387953,  0.9577693 ,  0.98171161,  0.99567723,  1.        ,  0.99153322,  0.97667972,  0.95464916,  0.92387953,  0.87961397,
        0.82876982,  0.77145882,  0.70710678,  0.63189446,  0.55256827,  0.46956353,  0.38268343,  0.28797475,  0.19224321,  0.09618145,  0.        ,
       -0.09978651, -0.19734913, -0.29184339, -0.38268343, -0.47235617, -0.55689686, -0.63543772, -0.70710678, -0.77448156, -0.83345506, -0.88344916,
       -0.92387953, -0.95744181, -0.98100832, -0.99507648, -1.        , -0.99781462, -0.98502457, -0.96048119, -0.92387953, -0.87791925, -0.82442951,
       -0.76694112, -0.70710678, -0.64316283, -0.57043491, -0.4840523 , -0.38268343])
>>> plot(z)
[<matplotlib.lines.Line2D object at 0x04286410>]
