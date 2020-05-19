# NuPIC for Julia

A work in progress. A Julia port of [NuPIC](https://github.com/numenta/nupic)

Numenta Platform for Intelligent Computing is an implementation of Hierarchical Temporal Memory (HTM), a theory of intelligence based strictly on the neuroscience of the neocortex. http://numenta.org/

I believe this library is an ideal candidate for porting to Julia. First it is already written in Python, a very similar language. Second, the library is self contained and relatively small without many dependencies. Third, the fundamental principals of the library are the subject of active research and could benefit from the ability to rapidly iterate new changes and features. Higher performance testing can be gained during a rapid iteration cycle resulting in higher fidelity test results. Lastly the Julia community is filled with many brilliant and imaginative people who would be able to contribute allot to this area of research.