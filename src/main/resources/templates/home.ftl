<!doctype html>
<html>

<head>
  <#include "_head.ftl">
  <title>Java DemoApp</title>
</head>

<body>
  <#include "_nav.ftl">
  <div class="container">

    <div class="jumbotron">
      <h2 class="index-head"><img src='img/java.svg' height='90px' /> Java Demo App</h2>
      <hr />
      <p class="lead">
        This is a simple Java web app built using Spring Boot. It has been designed with cloud
        demos & containers in mind. Demonstrating capabilities such as auto scaling, deployment to AWS or Kubernetes, or anytime you want
        something quick and lightweight to run & deploy 😄<br/><br/>Basic features:
        <ul>
            <li>System status / information view</li>
            <li>Authentication via Amazon Cognito</li>
            <li>AWS X-Ray support</li>
          </ul>
      </p>
      <br />

      <p>
        <img src='/img/octocat.png' width='58px' /> &nbsp;
        <a target='_blank' href='https://github.com/otterley/java-demoapp' class="btn btn-info btn-lg">Project on
          Github</a>
      </p>

      <hr />

      <p>
        <img src='/img/get-started.svg' width='58px' /> &nbsp;
        <a target='_blank' href='https://aws.amazon.com/developer/language/java/'
          class="btn btn-success btn-lg">Get started with AWS &amp; Java</a>
      </p>


      <br />
      <h4>AWS <i class="fa fa-heart"></i> Open Source</h4>
    </div>

  </div>
</body>

</html>