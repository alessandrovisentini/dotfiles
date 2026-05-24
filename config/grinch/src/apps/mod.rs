mod desktop;
mod launch;

pub use desktop::collect_apps;
pub use launch::launch_app;

#[derive(Clone)]
pub struct App {
    pub name: String,
    pub icon: String,
    pub exec: String,
    pub terminal: bool,
}
