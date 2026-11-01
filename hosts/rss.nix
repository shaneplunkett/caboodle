{
  imports = [
    ../modules/services/freshrss
  ];

  environment.etc."sha-279-proof".text = throw "SHA-279 proof: rss fails to evaluate";
}
