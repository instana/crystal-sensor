<div align="center">
<img src="https://user-images.githubusercontent.com/395132/28031672-5145e9d8-65a8-11e7-8d40-8fcfcc0166e7.png"/>
</div>

# Instana

The instana package provides Crystal metrics and traces (request, queue & cross-host) for [Instana](https://www.instana.com/).

Any and all feedback is welcome.  Happy Crystal visibility.

Note: _This package is currently in BETA._

[![OpenTracing Badge](https://img.shields.io/badge/OpenTracing-enabled-blue.svg)](http://opentracing.io)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  instana:
    github: instana/crystal-sensor
```

## Usage

```crystal
require "instana"
```

## Tracing

This Crystal shard supports [OpenTracing](http://opentracing.io/).

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://docs.instana.io/).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/crystal-sensor.

## More

Want to instrument other languages?  See our [Nodejs](https://github.com/instana/nodejs-sensor), [Go](https://github.com/instana/golang-sensor), [Ruby](https://github.com/instana/ruby-sensor), [Python](https://github.com/instana/python-sensor) instrumentation and [many other supported languages & technologies](https://www.instana.com/supported-technologies/).

## Contributors

- [pglombardo](https://github.com/pglombardo) Peter Giacomo Lombardo - creator, maintainer
