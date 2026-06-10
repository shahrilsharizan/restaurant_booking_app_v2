# Project Constraints
- Architecture: Feature-first (lib/src/features/)
- State Management: Riverpod (flutter_riverpod)
- Router: go_router
- Database Schema:
    * users (uid, full_name, username, email, role ['user'|'admin'])
    * packages (package_id, name, details, base_price_per_pax)
    * bookings (booking_id, uid, package_id, event_date, event_time, num_guests, total_price)