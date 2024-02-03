let navProto = Object.getPrototypeOf(window.navigator);
delete navProto.webdriver;
delete navigator.webdriver;
