from setuptools import setup

from pathlib import Path
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text()

setup(
    name='hostpreplib',
    version='0.1.0',
    packages=['hostpreplib'],
    url='https://github.com/couchbaselabs/couchbase-hostprep',
    license='Apache License 2.0',
    author='Michael Minichino',
    python_requires='>=3.8',
    install_requires=[
        'attrs',
        'dnspython',
        'docker',
        'pytest',
        'requests',
        'urllib3'
    ],
    author_email='info@unix.us.com',
    description='Host Configuration Automation Library',
    long_description=long_description,
    long_description_content_type='text/markdown',
    keywords=["couchbase", "syncgateway", "cloud", "automation"],
    classifiers=[
          "Development Status :: 4 - Beta",
          "License :: OSI Approved :: Apache Software License",
          "Intended Audience :: Developers",
          "Operating System :: OS Independent",
          "Programming Language :: Python",
          "Programming Language :: Python :: 3",
          "Topic :: Software Development :: Libraries",
          "Topic :: Software Development :: Libraries :: Python Modules"],
)
