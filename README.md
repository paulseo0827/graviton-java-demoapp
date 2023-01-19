# Java - Demo Web Application

This is a simple Java web app built using Spring Boot and OpenJDK 11.

The app has been designed with cloud native demos & containers in mind, in order to provide a real working application for deployment, something more than "hello-world" but with the minimum of pre-reqs. It is not intended as a complete example of a fully functioning architecture or complex software design.

Typical uses would be deployment to Kubernetes, demos of Docker, CI/CD (build pipelines are provided), deployment to cloud (AWS) monitoring, auto-scaling

The app has several basic pages accessed from the top navigation menu, some of which are only lit up when certain configuration variables are set (see 'Optional Features' below):

Features:

- The **'Info'** page displays some system basic information (OS, platform, CPUs, IP address etc) and should detect if the app is running as a container or not.
- The **'Tools'** page is useful in demos, and has options such a forcing CPU load (for autoscale demos), and error pages for use with App Insights
- The **'mBeans'** page is a basic Java mBeans explorer, letting you inspect mBeans registered with the JVM and the properties they are exposing
- Amazon Cognito support for user auth and sign-in (optional, see config below)
- AWS X-Ray monitoring (optional, see config below)

![](https://user-images.githubusercontent.com/14982936/71443390-87cd0680-2702-11ea-857c-63d34a6e1306.png)

# Building & Running Locally

### Pre-reqs

- Be using Linux, WSL or MacOS, with bash, make etc
- [Java 11+](https://adoptopenjdk.net/installation.html) - for running locally, linting, running tests etc
- [Docker](https://docs.docker.com/get-docker/) - for running as a container, or image build and push
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) - for deployment to AWS

Clone the project to any directory where you do development work

```
git clone https://github.com/otterley/java-demoapp.git
```

### Makefile

A standard GNU Make file is provided to help with running and building locally.

```text
help                 💬 This help message
lint                 🔎 Lint & format, will not fix but sets exit code on error
lint-fix             📜 Lint & format, will try to fix errors and modify code
image                🔨 Build container image from Dockerfile
push                 📤 Push container image to registry
run                  🏃 Run BOTH components locally using Vue CLI and Go server backend
deploy               🚀 Deploy to Amazon ECS
undeploy             💀 Remove from AWS
test                 🎯 JUnit tests for application
test-report          🎯 JUnit tests for application (with report output)
test-api             🚦 Run integration API tests, server must be running
clean                🧹 Clean up project
```

Make file variables and default values, pass these in when calling `make`, e.g. `make image IMAGE_REPO=blah/foo`

| Makefile Variable | Default      |
| ----------------- | ------------ |
| IMAGE_REG         | _none_       |
| IMAGE_REPO        | java-demoapp |
| IMAGE_TAG         | latest       |
| AWS_STACK_NAME    | java-demoapp |
| AWS_REGION        | us-west-2    |


The application listens on port 8080 by default, but this can be set with the `PORT` environmental variable.

# Containers

Should you want to build your own container, use `make image` and the above variables to customise the name & tag.

# Kubernetes

The app can easily be deployed to Kubernetes using Helm, see [deploy/kubernetes/readme.md](deploy/kubernetes/readme.md) for details

# Optional Features

### AWS X-Ray

🚧 Coming soon.

### User Authentication with Amazon Cognito

🚧 Coming soon.

Enable this by setting `COGNITO_IDENTITY_POOL_ID`.

# Updates

- Jul 2022 - Modified for AWS (Michael Fischer)
- Mar 2021 - Version bumps, unit tests
- Dec 2019 - First version
