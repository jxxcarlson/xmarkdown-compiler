The Schwarzschild Radius

The Schwarzschild radius is one of the simplest and most important quantities in black-hole physics. It is the radius of the event horizon of a non-rotating, uncharged black hole.

The formula is

| equation
r_s = \frac{2GM}{c^2}

where

- [m G] is Newton’s gravitational constant.
- [m M] is the mass of the object.
- [m c] is the speed of light.

At first sight this formula looks mysterious. Why should the size of a black hole be proportional to its mass? Why does the speed of light appear? And why is the factor exactly 2?

To answer these questions, it is useful to begin with a simple back-of-the-envelope argument.

# Escape Velocity

In Newtonian gravity, the escape velocity from the surface of a spherical body is obtained by equating kinetic and gravitational potential energy.

| equation
\frac12 mv^2 = \frac{GMm}{R}

Solving for [m v] gives

| equation
v_{\rm esc} = \sqrt{\frac{2GM}{R}}

Now imagine compressing a mass [m M] into a smaller and smaller sphere.
As the radius decreases, the escape velocity increases.
Suppose the escape velocity becomes equal to the speed of light.

| equation
c = \sqrt{\frac{2GM}{R}}

Squaring both sides gives

| equation
c^2 = \frac{2GM}{R}

and therefore

| equation
R = \frac{2GM}{c^2}

which is exactly the Schwarzschild radius.

This argument is not a derivation. Black holes require general relativity, not Newtonian gravity. Nevertheless, the fact that the Newtonian argument produces the correct formula is remarkable and provides useful intuition.
The Schwarzschild radius is the radius at which even light cannot escape.

# Historical Remark

The above argument was essentially made in the eighteenth century by the English scientist John Michell and independently by the French mathematician Pierre-Simon Laplace.
They imagined “dark stars” whose escape velocity exceeded the speed of light.

What they lacked was Einstein’s understanding that gravity is not a force acting in space but rather a manifestation of the geometry of spacetime.

# Schwarzschild’s Solution

In 1915 Einstein published the field equations of general relativity.  Soon afterward, Karl Schwarzschild found the first exact solution.
The Schwarzschild metric is

| equation
ds^2 =
-\left(1-\frac{2GM}{c^2r}\right)c^2dt^2
+
\left(1-\frac{2GM}{c^2r}\right)^{-1}dr^2
+
r^2d\Omega^2

This metric describes the spacetime outside a spherical mass. Notice the appearance of the factor

| equation
1-\frac{2GM}{c^2r}

When

| equation
r=\frac{2GM}{c^2}

this factor becomes zero.

That radius is precisely the Schwarzschild radius.
The event horizon appears naturally as a geometric feature of spacetime.
What Happens at the Horizon?
The horizon is not a material surface.
There is no wall. There is no membrane.
A freely falling observer crossing the horizon experiences nothing locally unusual, provided the black hole is sufficiently large.

The horizon is instead a causal boundary.
Events inside the horizon cannot send signals to the outside universe.
The key idea is that all future-directed paths inside the horizon point toward smaller values of [m r].

Just as tomorrow is unavoidable, reaching the singularity becomes unavoidable.
Inside the horizon, moving toward smaller [m r] is as inevitable as moving toward the future.

# Gravitational Redshift

One way to understand the horizon is through gravitational redshift.
A photon emitted at radius [m r] and received far away has its frequency reduced by

| equation
\nu_\infty
=
\nu_r
\sqrt{1-\frac{2GM}{c^2r}}

As the source approaches the Schwarzschild radius,

| equation
r \to r_s

the square-root factor approaches zero.
Consequently,

| equation
\nu_\infty \to 0

The photon becomes infinitely redshifted.
From the viewpoint of a distant observer, clocks near the horizon appear to run ever more slowly.

# Time Dilation

The Schwarzschild metric predicts that a clock at radius [m r] runs more slowly than a clock far away.

| equation
d\tau
=
dt
\sqrt{1-\frac{2GM}{c^2r}}

As

| equation
r \to r_s

the factor approaches zero.
Thus, from the perspective of a distant observer, time appears to stop at the horizon.
This is one reason black holes originally seemed paradoxical.

The paradox disappears when one recognizes that the slowing of time is observer-dependent.
The infalling observer crosses the horizon in finite proper time.

# Typical Sizes

The Schwarzschild radius is surprisingly small.
For the Earth,

| equation
r_s \approx 8.9\ {\rm mm}

If the entire Earth could be compressed into a sphere about the size of a marble, it would become a black hole.
For the Sun,

| equation
r_s \approx 2.95\ {\rm km}

A sphere roughly six kilometers in diameter containing the Sun’s mass would be a black hole.
For a black hole of ten solar masses,

| equation
r_s \approx 30\ {\rm km}

For the supermassive black hole at the center of our galaxy,

| equation
M \approx 4\times10^6 M_\odot

and

| equation
r_s \approx 1.2\times10^7\ {\rm km}

which is about seventeen times the radius of the Sun.

# Density Paradox

Many people imagine black holes as extraordinarily dense objects.
This is true for small black holes, but not necessarily for large ones.
The average density inside a Schwarzschild radius is

| equation
\rho

\frac{3M}{4\pi r_s^3}

Substituting

| equation
r_s=\frac{2GM}{c^2}

gives

| equation
\rho
=
\frac{3c^6}
{32\pi G^3M^2}

Thus

| equation
\rho \propto \frac{1}{M^2}

As the mass increases, the average density decreases.
A sufficiently massive black hole can have an average density comparable to water or even air.
This surprising result occurs because the radius grows linearly with mass while the enclosed volume grows as the cube of the radius.

# Dimensional Analysis

The Schwarzschild radius can almost be guessed from dimensional analysis.
We seek a length built from

- [m G]
- [m M]
- [m c]

The dimensions are

| equation
[G] = \frac{L^3}{MT^2}

| equation
[M] = M

| equation
[c] = \frac{L}{T}

Combining them,

| equation
\frac{GM}{c^2}

has dimensions

| equation
\frac{L^3}{MT^2}
\frac{M}{L^2/T^2}
L

Thus

| equation
r_s \propto \frac{GM}{c^2}

General relativity determines the numerical coefficient to be exactly 2.

# Why the Radius Matters

The Schwarzschild radius sets the fundamental scale for nearly every physical property of a black hole. The horizon area is

| equation
A = 4\pi r_s^2

The Hawking temperature is

| equation
T_H
=
\frac{\hbar c}
{4\pi k_B r_s}

The entropy is

| equation
S
=
\frac{k_B A}
{4\ell_P^2}

where [m \ell_P] is the Planck length.
Thus once the Schwarzschild radius is known, the thermodynamic properties of the black hole follow.

# The Deep Idea

The Schwarzschild radius is not merely a geometric size.
It marks the location where spacetime becomes so strongly curved that the structure of causality changes.
Outside the radius, light can move both inward and outward.
Inside the radius, every future-directed trajectory leads inward.
The horizon therefore separates two regions of spacetime with fundamentally different causal structures.
The simple formula

| equation
r_s = \frac{2GM}{c^2}

captures the point at which gravity becomes so strong that space and time exchange roles, light cannot escape, and a black hole is born.
It is one of the most compact and profound equations in all of physics.
