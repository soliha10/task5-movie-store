export function renderTemplate(template, target) {
  target.replaceChildren(template.content.cloneNode(true))
}
