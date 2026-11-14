// Lazy-load Stimulus controllers on demand so pages only download controllers they mount
import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("controllers", application)
