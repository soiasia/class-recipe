$ ->
  $('.flexslider:not(:last)').flexslider
    animation: "slider",
    animationSpeed: 300,
    controlNav: true,
    smoothHeight: true,
    slideshow: false

  $('.flexslider:last').flexslider
    animation: "slider",
    animationSpeed: 300,
    controlNav: true,
    smoothHeight: true,
    slideshow: false

$(window).on "load" , ->
  $(".projects").packery
    itemSelector: ".project",
    gutter: 20
