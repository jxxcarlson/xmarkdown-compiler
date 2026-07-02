const init = async function(app) {

  console.log("I am starting elm-katex: init");

  var katexJs = document.createElement('script');
  katexJs.type = 'text/javascript';
  katexJs.onload = function() {
    console.log("elm-katex: katex loading");
    initKatex();
    console.log("elm-katex: mhchem loading");
    loadMhchem();
  };
  katexJs.src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js";

  document.head.appendChild(katexJs);
  console.log("elm-katex: I have appended katexJs to document.head");
}

function loadMhchem() {
  var mhChemJs = document.createElement('script');
  mhChemJs.type = 'text/javascript';
  mhChemJs.onload = function() {
    console.log("elm-katex: mhchem loaded");
  };
  mhChemJs.src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/mhchem.min.js";

  document.head.appendChild(mhChemJs);
  console.log("elm-katex: I have appended mhChemJs to document.head");
}

function initKatex() {
  console.log("elm-katex: initializing katex");

  class MathText extends HTMLElement {
    constructor() {
      super();
      console.log("elm-katex: MathText constructor called");
    }

    connectedCallback() {
      console.log("elm-katex: MathText connectedCallback triggered");
      try {
        const content = this.getAttribute('data-content') || this.textContent || '';
        const displayMode = this.getAttribute('data-display') === 'true';

        console.log("elm-katex: rendering content:", content.substring(0, 50), "displayMode:", displayMode);

        if (!content || !window.katex) {
          console.warn("elm-katex: missing content or katex not available", {hasContent: !!content, hasKatex: !!window.katex});
          return;
        }

        this.attachShadow({mode: "open"});
        const rendered = window.katex.renderToString(content, {
          throwOnError: false,
          displayMode: displayMode,
          trust: true // Allows mhchem to be used
        });

        this.shadowRoot.innerHTML = rendered;

        let link = document.createElement('link');
        link.setAttribute('rel', 'stylesheet');
        link.setAttribute('href', 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css');
        this.shadowRoot.appendChild(link);

        console.log("elm-katex: successfully rendered math element");
      } catch (e) {
        console.error("elm-katex: error rendering", e);
      }
    }
  }

  console.log("elm-katex: defining custom element");
  customElements.define('math-text', MathText);
  console.log("elm-katex: custom element defined");
}
