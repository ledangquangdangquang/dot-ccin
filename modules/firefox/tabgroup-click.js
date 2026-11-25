// Left-click a tab group label: open the built-in group preview dropdown instead of expand/collapse.
try {
  Services.obs.addObserver((win) => {
    win.addEventListener("click", (e) => {
      const gb = win.gBrowser;
      if (e.button !== 0 || !gb?.isTabGroupLabel(e.target)) return;
      e.stopPropagation();
      e.preventDefault();
      const group = e.target.group;
      group.collapsed = true; // preview only shows for collapsed groups
      gb.tabContainer.showTabGroupPreview(group);
    }, true);
  }, "browser-delayed-startup-finished");
} catch (e) {
  Components.utils.reportError(e);
}
