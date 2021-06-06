function LoadCSS(cssURL) {
  // 'cssURL' is the stylesheet's URL, i.e. /css/styles.css
  return new Promise(function (resolve, reject) {
    var link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = cssURL;
    document.head.appendChild(link);
    link.onload = function () {
      resolve();
      console.log("CSS has loaded!");
    };
  });
}

function loadMyCss(url) {
  let element = document.createElement("link");
  element.setAttribute("rel", "stylesheet");
  element.setAttribute("type", "text/css");
  element.setAttribute("href", url);
  document.getElementsByTagName("head")[0].appendChild(element);
}

function loadCSSText(css) {
  let s = document.createElement("style");
  s.innerHTML = css;
  document.getElementsByTagName("head")[0].appendChild(s);
}
