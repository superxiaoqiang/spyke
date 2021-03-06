"""spyke installation script

to do a normal installation:
>> python setup.py install

to build extensions in-place for development:
>>> python setup.py build_ext --inplace
(you might need to add --compiler=mingw32 if you're in win32 and mingw isn't your default compiler in Python)

to create source distribution and force tar.gz file:
>>> python setup.py sdist --formats=gztar

to create binary distribution:
>>> python setup.py bdist_wininst

NOTE: Make sure there's a MANIFEST.in that includes all the files you want to place
in the tarball. See http://wiki.python.org/moin/DistUtilsTutorial
"""

from distutils.core import setup#, Extension
from spyke.__init__ import __version__

#import sys
#from Cython.Distutils import build_ext

'''

# modify this to point to your numpy/core/include
if sys.platform == 'win32':
    include_dirs=['/bin/Python25/Lib/site-packages/numpy/core/include']
elif sys.platform == 'linux2':
    include_dirs=['/usr/lib/python2.5/site-packages/numpy/core/include']
else:
    raise RuntimeError
simple_detect_cy = Extension('spyke.simple_detect_cy',
                             sources=['spyke/simple_detect_cy.pyx'],
                             include_dirs=include_dirs,
                             #extra_compile_args=["-g"], # debug
                             #extra_link_args=["-g"],
                             )
detect_cy = Extension('spyke.detect_cy',
                      sources=['spyke/detect_cy.pyx'],
                      include_dirs=include_dirs,
                      #extra_compile_args=["-g"], # debug
                      #extra_link_args=["-g"],
                      )

cython_test = Extension('demo.cython_test',
                        sources=['demo/cython_test.pyx'],
                        include_dirs=include_dirs,
                        #extra_compile_args=["-g"], # debug
                        #extra_link_args=["-g"],
                        )

cy_thread_test = Extension('demo.cy_thread_test',
                        sources=['demo/cy_thread_test.pyx'],
                        include_dirs=include_dirs,
                        #extra_compile_args=["-g"], # debug
                        #extra_link_args=["-g"],
                        )
'''
spyke_files = ["res/*.png"] # list of extra (non .py) files required by the spyke package, relative to its path

setup(name='spyke',
      version=__version__,
      license='BSD',
      description='Multichannel spike viewer and sorter for Swindale Lab .srf files',
      author='Martin Spacek, Reza Lotun',
      author_email='git at mspacek mm st',
      url='http://spyke.github.io',
      #long_description='',
      packages=['spyke'], # have to explicitly include subfolders with code as additional packages
      package_data={'spyke' : spyke_files},
      #cmdclass={'build_ext': build_ext},
      #ext_modules=[#simple_detect_cy,
      #             detect_cy,
      #             cython_test,
      #             cy_thread_test
      #             ],
      )
