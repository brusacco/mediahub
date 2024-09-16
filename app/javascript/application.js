// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

document.addEventListener("turbo:load", function() {
  // Toggle para el menú de usuario (Cerrar Sesión)
  var userMenuButton = document.getElementById('user-menu-button');
  var userMenu = document.getElementById('user-menu');

  userMenuButton.addEventListener('click', function(event) {
    userMenu.classList.toggle('hidden');
    event.stopPropagation();
  });

  // Toggle para el menú de tópicos
  var topicsMenuButton = document.getElementById('topics-menu-button');
  var topicsMenu = document.getElementById('topics-menu');

  topicsMenuButton.addEventListener('click', function(event) {
    topicsMenu.classList.toggle('hidden');
    event.stopPropagation();
  });

  // Ocultar menús cuando se hace clic fuera de ellos
  document.addEventListener('click', function() {
    if (!userMenu.classList.contains('hidden')) {
      userMenu.classList.add('hidden');
    }
    if (!topicsMenu.classList.contains('hidden')) {
      topicsMenu.classList.add('hidden');
    }
  });

  // Prevenir cierre de menús al hacer clic dentro de ellos
  topicsMenu.addEventListener('click', function(event) {
    event.stopPropagation();
  });
});