| [![5G-VICTORI logo](images/5g-victori-logo.png)](https://www.5g-victori-project.eu/) | This project has received funding from the European Union’s Horizon 2020 research and innovation programme under grant agreement No 857201. The European Commission assumes no responsibility for any content of this repository. | [![Acknowledgement: This project has received funding from the European Union’s Horizon 2020 research and innovation programme under grant agreement No 857201.](images/eu-flag.jpg)](https://ec.europa.eu/programmes/horizon2020/en) |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |


# Platform

This document describes a system for the prefilling of media caches on trains developed in the EU funded R&D prject [5G-VICTORI](https://www.5g-victori-project.eu/). Caching shall ensure availability of streaming content, even if the trains have no connection to the Internet. Via a train's on-board WiFi, passengers can stream the content from the cache to their personal mobile devices without interruption and without having to worry about their mobile data plans. The system can be integrated into the conventional distribution infrastructure of streaming services. Passengers can thus use the conventional apps of the streaming service.

This page covers information on the following topics:

- [Concept](#concept): how does the system operate and what influenced its design
- [System Architecture](#architecture) and a description of its individual components
- [Communication](#communication) between the system components
- [Technology](#technology) involved in the implementation of the system

Besides the documentation of the system, this repository contains scripts to [install, build and run](#install-build-run) the system on a development machine.

## Concept

Streaming services usually deliver their content via so-called content delivery networks (CDNs). These are Internet overlay networks of servers (caches) at strategic nodes of the Internet. The caches hold copies of content so that it reaches users faster. Also, CDNs enable a higher level of service reliability and can be designed to optimise the distribution of network load and transmission costs. Our approach is to extend the streaming service’s CDN to trains by equipping them with caches. Caches are filled with content via wireless data links. In the 5G-VICTORI scenario these are realised by dedicated local 5G data connections – "data showers" – with data rates of up to 20 GBit/s. Data showers are installed at selected locations along the train route – initially at train stations.

![Simplified topology of the extended content delivery network: streaming content gets to people’s households via a CDN, which gets extended by caches on trains. Caches on trains are filled via local 5G radio links in train stations.](https://docs.google.com/drawings/d/1_5STxtvcBSTZ8qXg2ApVjtL-54GbkuAGFDcc5c0eijk/export/svg)

This approach has the following advantages. First, content licenses which streaming services have already purchased for conventional distribution via the Internet are valid. It would be different, if the streaming service offered its content via a portal of the train company. In this setup the train company would become a third party provider and thus a further entity in the exploitation chain. In our setup, the train company is merely the provider or host of distribution infrastructure. The legal situation is therefore the same as with classic CDNs. A second advantage is that passengers can use the regular app of a streaming service (web or mobile), which they might have already installed on their personal device. Once connected to the on-train WiFi, users will experience high-quality on-demand video without any strain on their mobile data budget. Due to the possible update rates, streaming services can also offer current affairs programmes such as news.

For the cache on the train we don't want to reinvent the wheel and rely on standard solutions that are mature in terms of performance and have proven themselves in large scale deployments. NGINX is widely used for such purposes, [like in NETFLIX' own CDN](https://www.nginx.com/blog/why-netflix-chose-nginx-as-the-heart-of-its-cdn/) "[Open Connect](https://openconnect.netflix.com/en/)". To use NGINX as a cache, it is operated in reverse proxy mode. Requests for which NGINX has stored a response will be answered directly. For others, NGINX first loads the response from the upstream location and then delivers it. Like other caching solutions, NGINX does not provide an interface to push content into the cache. Although NGINX is an open source project and we could make necessary adaptations, we do not want to be too dependent on a specific software product. Therefore our approach is to send requests to the reverse proxy cache for the content that we want to be available in the cache later.

In most cases, not all content of a VoD service's catalogue will fit into the cache on the train. High demands are placed on hardware installed in trains, for example with regards to energy consumption, temperature development and reliability. Accordingly, the hardware is expensive. Content catalogues of large VoD services like [ARD-Mediathek](https://www.ardmediathek.de/ard/) have a storage requirement of well over 100TB. Storage space of this size is no bargain even in the consumer segment. At the latest when several VoD services want to offer their services in the train, storage space becomes scarce and each service has to make a choice about which content should be available in the train. Our system currently provides for editorial preselection of content based on rules. It is conceivable that this will later be supplemented or replaced by an automatic selection system, which forecasts what passenger will want to watch – similar to recommendation engines.

In the following section we will take a closer look at the system's specific components and their role in the fullfillment of the requirements described above.

## Architecture

This section overviews the archtecture of the system from two perspctives. In section [component architecture](#component-architecture) we first describe the functional building blocks which allow the system to behave in a certain way. Here the logical flow of information between the components is also described. The first proof-of-concept implementation of the caching system was made using the VoD service ARD-Mediathek as an example. The content derlivery of the ARD-Mediathek has some peculiarities, which are mainly due to the heterogeneity of the content sources. The adjustments that are necessary due to these peculiarities are discussed in the [subsequent subsection](#adaptations-specific-to-ard-mediathek). After that we explain the [technical solution](#technical-solution). The functional components are supplemented by further components, which are primarily to help the system to meet non-functional requirements like availability and reliability. Here we also explain, which path messages actually take between the components. Details on the actual messages exchanged between components are however only dealt with in the chapter [Communication](#communication). Information to the used technologies is given in the chapter [Technology](#technology).

### Component Architecture

The below diagram overviews functional building blocks of the system. It can be decomposed into online and offline components. Online components are assumed to have a continuous connection to the Internet and may be hosted in the cloud or, in the case of the online cache more likely, on computing resources physically close to the radio link equpiment, for example at a data synchronisation access point in a train station. The diagram shows components of the system as well as involved backend services and client applications of the VoD service provider. Arrows between components symbolize the logical flow of information. The technical implementation of the interaction between components will be discussed in more detail in sections [Technical Solution](#technical-solution) and [Communication](#communication).

![Architecture](https://docs.google.com/drawings/d/1XlJ4T_C6AbH8JhqdxtZE2jHtYLxgXi3LHTXiwoVPYc0/export/svg)

In the following we explain the roles of the components of the caching system shown in the diagram. Details on the functionality, implementation and the current development status can be found in the respective git repositories.

- **[Configurator UI](../../../5gv-configurator-ui)**: is a web based user interface intended for editorial staff of the VoD service provide. Editors can define a number of rules with which they determine which content the cache should be filled with. A rule consists of a criterion and a number. The number determines how many videos that meet this criterion should be loaded into the cache. Criterions may relate to the usage of the video service (e.g. "top views of the last 7 days"), to content characteristics (e.g. "Latest episodes of series XYZ") or the release date of the content item. Configurations are sent to the Aggregator service.
- **[Aggregator](../../../5gv-aggregator)**: receives configurations from the Configurator UI. It searches different data sources of the VoD service provider, e.g. the content archive or business intelligence data, for content which matches the configuration. The Aggregator retrieves resource locations of the matching content in the VoD service providers content delivery network. For adaptive bitrate streams it parses the streams manifest files and retrieves locations of the stream segments. Finally, it compiles a list of resource locations and sends it to the to the Cache Monitor service, which subsequently informs the Prefetcher service which content items are missing in the Cache.
- **[Prefetcher](../../../5gv-prefetcher)**: Receives the list of content items missing in the Cache from the Cache Monitor. Requests resources on that list from the Cache in the train station.
- **[Cache](../../../5gv-cache)**: the actual media cache. There are two instances in the above diagram. The "Online Cache", instances of which are located at content synchronisation access points along the train track. An Online Cache acts as a buffer between the VoD service's CDN and the "Offline Cache" on the train to ensure that content can be delivered to Offline Cache at the data rate provided by the radio link.
- **[Cache Monitor](../../../5gv-cache-monitor)**: receives the list of the required media items from the aggregator. Monitors the Cache and checks which media items are available or missing in the cache.
- **Sync Controller**: Monitors the connection status of the train to a synchronisation access point. If connected, the Sync Controller triggers a data synchronisation mechanism which ensures that the offline cache holds the same set of media item files as the online cache. So far there is no implementation of the sync controller. The implementation of the connection status control depends mainly on the modem hardware used in the train (be it 5G or another wireless transmission network). For data synchronisation, one should certainly first evaluate the suitability of common data synchronization protocols such as [rsync](https://en.wikipedia.org/wiki/Rsync).
- **[(Sample) Streaming App](../../../5gv-sample-streaming-client)**: client application running on the passengers personal device. It can be Web browser based or a native application (e.g. Android or iOS). Typically the streaming app would be the usual of-the-shelf streaming app of a VoD service. The streaming app can be modified to recognise that it is running on a train equipped with the caching system (e.g. IP range filter). It can than query the Cache Monitor for availabile media items and adapt the user interface acordingly. For example it could sort media items on the apps landing page according to availability or indicate the availability of media items through a dedicated icon.

### Adaptations specific to ARD-Mediathek

The ARD-Mediathek is the joint VoD portal of the 14 broadcasting stations of the working group of the regional public-service broadcasters in Germany ([ARD](<https://en.wikipedia.org/wiki/ARD_(broadcaster)>)). Each regional broadcaster takes care of the distribution of its content itself and makes its own contracts with CDN providers. Accordingly, the contents are also accessible under different domain names. Some broadcasters also conclude contracts with several CDN providers in order to be able to switch dynamically between CDNs and to optimize costs and availability of distribution. Thus, content in ARD-Mediathek is delivered via a large number of domain names -- the order of magnitude well exceeds 20. As the ARD-Mediathek application on the train is to retrieve them directly from the cache, this would require a lot of organisational and maintenance effort due to two main reasons. First, the local DNS in the onboard network would have to be configured so that all requests to these domains are routed to the local cache. Second, the cache would have to hold all SSL certificates for these domains in order to terminate the corresponding HTTPS connections.

To deal with this level of complexity, we apply an ARD development which intents to optimise online distribution over several CDNs. The core concept of the development relies on player-side switching between CDNs. From a resover service, the player receives the information from which CDNs it should load a certain content item. The resolver service can also determine how large the portions of a particular stream are to be obtained over one or the other CDN. We adopt this approach and the respective fork of the player development of the ARD-Mediathek in our [Sample Streaming App](../../../5gv-sample-streaming-client). We install the resolver service on the train and therefore call it Train Resolver. The [**Train Resolver**](../../../5gv-train-resolver) is set up to instruct the players to retrieve all content from the Offline Cache. Manifests of HLS streams in the ARD-Mediathek usually contain absolute URLs to the stream segments. We therefore have to replace the hostnames in the cached manifest files with the hostname of the cache. This is the task of the [**Manifest Transformer**](../../../5gv-manifest-transformer). The Offline Cache redirects all requests for HLS Manifest to the Manifest Transformer. The Manifest Transformer then delivers the manipulated resource to the cache, which stores it. The diagram below shows how the [component architecture](#component-architecture) is supplemented by the two additional components.

![ARD-Mediathek specific adaptations to the comonent architecture](https://docs.google.com/drawings/d/1LhU2vxCSr8UDMrLtNi5PGUfM6WjsoQHBnK7M3ReMDsA/export/svg)

### Technical Solution

The below diagram overviews the technical solution. It supplements the [Component Architecture](#component-architecture) by a set of components that facilitate communication, information persistence and system monitoring. In the following we will explain the purpose of the individual components and the technical information flow in the system. Individual messages exchanged between services will be handled in section [Communication](#communication). The diagram depicts the individual technologies and frameworks used to implement the services. These will be covered in the later section on [Technology](#technology).

![Technichnical solution diagram](https://docs.google.com/drawings/d/12H39Mcl5Zj_uFRGGxgWtBxgbzTO9cEpoOPJ-7fjiJtk/export/svg)

The diagram provides different levels of information. It shows structural units. These include the components from the component architecture, which are realized as web services. They are framed by dashed grey boxes indicating that certain services should be executed on the same physical or virtual machine. This is the case, for example, for the Cache Monitor and the Online Cache. The Cache Monitor monitors the file system of the Online Cache. The file system could be mounted over an IP network, but then the monitoring would not be as reliable. The grey boxes can be used later to derive a deployment infrastructure which could be provided for example by an [IaaS](https://en.wikipedia.org/wiki/Infrastructure_as_a_service) provider. The blue dotted boxes indicate external services that run on an external infrastructure, such as the VoD service databases (content archives and usage data) and the conventional CDN. The diagram also uses logos to visualize which technologies and frameworks were used to implement the individual components. In addition the diagram contains some components which were not depicted in the component architecture. These facilitate communication between the components, the persistence of the system state, as well as the system monitoring. The diagram shows only online components, which are the components on the left-hand side of the radio link in the [component diagram](#component-architecture).

Except for the HTTP GET requests of the prefetcher for content items to the cache, there is no direct communication between the components of the [component diagram](#component-architecture). Instead, the components are informed about changes in the system status. To do so, they register (publish-subscribe) with the **[Message Streamer](../../../5gv-message-broker)** service for certain types of status notifications (topics). If a status update occurs, observers will receive an HTTP URL where they can retrieve the corresponding information. The Message Streamer supports message replay. That means, if a service registers for a topic, it will receive the last published message for this topic. The **State DB** (data base) is responsible for the persistence of the system state. Via the **[State API](../../../5gv-state-api)** information about the state can be queried or changed.

This approach has advantages in terms of data consistency and fault tolerance. The information about the system status is kept centrally, the components do not have to worry about keeping their knowledge about the status consistent between each other. If one service fails, the other services can continue to work independently based on the central system status. If the failed service recovers, message replay informs it where it can call up the current system status in order to continue its work where it failed. The disadvantage is that the State DB and Message Streamer become single-point-off failures. However, these components are based on proven standard technologies, for whose operation architectures have been tested that make these points in the system robust against failures, for example a redundant design.

Information about service execution, such as debug and error logs, and performance metrics: Network, CPU and memory usage, but also the general health of the services are collected by data shippers and sent to a central database (**Log DB**). An analysis service (**Log Analytics**) service offers a graphical user interface (**Analystics UI**) for the knowledge discovery in the logged data.

## Communication

This section documents provides links to more in depth documentation of relevant repositories regarding the messages exchanged between services and APIs of service to which messages are sent.

### Topics

Services can register for the following topics with the message broker service via the **[Messenger](../../../5gv-messenger)** client:

- `new-aggregator-config`: A new configuration is available. A new message of this type is typically preceeded by a user applying a new configuration via the Configurator UI. This message is consumed by:
  - Aggregator: loads new config and processes it
  - Prefetcher: stops execution of current media item list until it receives a `new-cache-state` message
- `new-cache-state`: A new cache state is available. If the Aggregator receives a new configuration it searches the data base of the VoD service provider for maching content (see [component architecture](#component-architecture)). Once done, the Aggregator sends the aggregation result to the State API which initialises data base entries to capture the caching status of each media item to be cached. Subscribers to this message get a set of HTTP URLs. Via these URL they can query and change the status of media items respectively. This message is consumed by the following services:
  - Prefetcher: queries missing media items and requests them form the Online Cache
  - Cache Monitor: oberserves Online Cache with regards to changes of the availability of media items.

### State API

The REST API of the State API is documented in the [State API](../../../5gv-state-api) repository.

### Format of messages

Services exchange JSON formated strings. Structure of the objects exchanged is defined through data transfer object (DTO) implementations. Implementation and documentation of DTOs are maintained in the [DTO](../../../5gv-dto) repository.

## Technology

We use a number of common technologies and frameworks for the development of the [graphical user interfaces](#gui) and the [web services](#web-service) that compose the platform. For [monitoring](#monitoring) the services we use components of the popular [ELK stack](https://www.elastic.co/what-is/elk-stack).

### GUI

- [AngularJS](https://angularjs.org/): front-end web framework for developing single-page applications.

### Web Service

- [NestJS](https://nestjs.com/): framework for building Node.js based web services. Uses similar concepts and project structure as Angular.js. Allows keeping a homogenuous structure across back-end and front-end projects.
- [NATS streaming](https://docs.nats.io/nats-streaming-concepts/intro): messaging service which supports message replay. If a consumer drops it can receive the last sent message for a given topic again.
- [NGINX](https://nginx.org/en/): state of play reverse proxy cache
- [Mongo DB](https://www.mongodb.com/de) document oriented data base

### Monitoring

- [Elastic Search](https://www.elastic.co/elasticsearch/): distributed document-oriented search engine which that has proven useful in practice for storing and searching log data.
- [Kibana](https://www.elastic.co/kibana): Visual analytics tool for exploring elastic search.
- [Beats](https://www.elastic.co/beats/): data shippers which feed information on various aspects of the systems performance to elastic search.
  - [Filebeat](https://www.elastic.co/beats/filebeat): Ships content of files typically log files
  - [Metricbeat](https://www.elastic.co/beats/metricbeat): Ships system load metrics (CPU, memory)
  - [Heartbeat](https://www.elastic.co/beats/heartbeat): Ships information on the service health
  - [Packetbeat](https://www.elastic.co/beats/packetbeat): Ships information on the network load

### Packaging / Deployment

- [Docker](https://www.docker.com/resources/what-container): a tool for building and containerizing applications
- [Docker Compose](https://docs.docker.com/compose/): a tool for defining and running multi-container Docker applications

## Install, build, run

**Prerequesits**:

- [Docker](https://docs.docker.com/engine/install/ubuntu/)
- [docker-compose](https://docs.docker.com/compose/install/)

**Before**:

Before you actually run the startup script, make sure no process on your local machine is using any of the following network ports:

- `3000`
- `3002`
- `4222`
- `8080`
- `8222`

You can check which ports are used by which process running following command:

```bash
sudo netstat -tulpn
```

Check the respective manual on how to stop services which use conflicting ports. Alternatively, but rather rude, use the `kill` command to stop the respective process. `kill` consumes the process id ( `pid` ) you got from the listing through `sudo netstat -tulpn` : `sudo kill <pid>` .

In order to run the [Sample Streaming Client](../../../5gv-sample-streaming-client) on your local machine your DNS needs to be set to resolve service name "cache" to your local machine. You can achieve this for example by configuring dnsmasq on your Linux environment as follows:

**Run**:

```bash
$ ./up.sh <private_key_name>
```

`private_key_name` ist the name of the private ssh key you use to authenticate via ssh at the 5G-VICTORI git repository.

The script will:

- Clone (if not yet available in the current working directory) or pull updates for all relevant repositories
- Stop and remove existing Docker containers and remove all images derived from these repositories
- Build images from descriptions in Dockerfile in these repositories
- Start Docker containers derived from these images and run them on a common docker network through docker-compose

On subsequent platform start up, if you are not interested in integrating updates from the services' git repositories, you may also want to call docker compose directly to launch the platform. Exectution will be much faster as updates are not pulled and service images are not rebuild:

```bash
$ docker-compose up -d
```

The option `-d` tells docker compose to run in background and not to write container logs to the console. The combined logs of all service are very noisy and practically not readable anyways.

**Stop**:

To stop all services you may want to run:

```bash
./down.sh
```

which is basically a shortcut for `docker-compose down`

**Watch**:

To see whats happening (e.g. services console logs) you can use [Kitematic](https://github.com/docker/kitematic/releases).

Alternatively log into containers via command line:

```bash
docker exec -it <container_name> /bin/bash
```

## Known issues

### Execution of `up.sh` stalls

**What happens**: Sometimes execution of the `up.sh` script stalls.

**Cause**: _Not clear_

**How to handle**: Make sure you have the correct access rights for the Git repositories and setup the SSH keys properly. Stop current execution (`[ctrl] + [c]`) and restart. If you observe the same process stalling at the same step. Consider building the respective service manually. Information on how to build docker images manually is given in the readme files of the git repositories of the respective services.

## TODOs

### Mongo DB user and Password

Currently [`docker-compose.yml`](docker-compose.yml) contains hardcoded and unencryped password and user name for authentication at the MongoDB that makes up the State DB. Before moving the system to a production environment, it should be checked if this is in line with best practices or if this should be replaced by more elabporate user management and authentication techniques.

### Monitoring

The monitoring concept as described in the section [Technical Solution](#technical-solution) has not yet been implemented. However, it should be possible to implement it without changes to the source code of existing services. Only the log utilities of the services need to be configured so that they write log to files instead of the console. [Data shippers](https://www.elastic.co/de/beats/) from the [Elastik-Universe](https://www.elastic.co/de/elastic-stack) can be integrated via the [Docker Compose](docker-compose.yml) configuration. Docker volumes can be used to make the logs of the services accessible to the data shippers. The log database [Elastik Search](https://www.elastic.co/de/elasticsearch/) and the analytics tool [Kibana](https://www.elastic.co/de/kibana) as well as other data shippers for network and system load as well as service health can also be integrated via Docker Compose. The standard images from the Docker Hub should be applicable out of the box and only need to be supplemented with appropriate configuration files.

### Sync Controller

So far there is no implementation of the sync controller. The implementation of the connection status control depends mainly on the modem hardware used in the train (be it 5G or another wireless transmission network). For data synchronisation, one should certainly first evaluate the suitability of common data synchronization protocols such as [rsync](https://en.wikipedia.org/wiki/Rsync).

### Two-tier Online Cache

In the current architecture, data synchronisation access points each have a cache that pre-buffers content to allow delivery at a high data rate to the cache on the train. If the contents in the cache are updated at the access point, the cache can become inconsistent. This means that for some or even for all content items stream segments are missing. Therefore, at least two caches should be installed at access points, with one of the caches being consistent and serving as the source for data synchronization and one being used for preloading new content. For data synchronization, the cache with the latest consistent data is selected. Instead of two caches it could also be feasible to use one cache with two memory areas.

![Component architecture for a two-tier online cache with staging environment for loading updates](https://docs.google.com/drawings/d/1TVpIZhbNiDq7G4CLG462_AbTxy7fVTYi9lwTpfpF4Xw/export/svg)

The figure above shows a concept for a possible integration into the [component architecture](#component-architecture). A Cache Gateway gets informed by the Cache Monitor which cache is consistent and forwards requests adaptively. The inconsistent cache is always requested by the prefetcher. The offline cache is synchronized with the consistent cache.

### API Gateway

Consider introduction of an API Gateway to the [technical solution architecture](#technical-solution), which handles HTTP access between components and from outside the system. The API Gateway could handle following tasks:

- Load balancing
- Routing (might also do the trick for routing requests to the [two-tier cache](#two-tier-online-cache))
- Authentication

A candidate off-the-shelf solution for the purpose is [KONG](https://konghq.com/).
