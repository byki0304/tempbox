self.addEventListener('fetch', (event) => {
  const url = event.request.url || '';
  if (/firebasestorage|storage\.googleapis|drive\.google|googleusercontent|\/storage\/|\/thumb\/|\/upload\/|X-Goog-|Signature=|token=/i.test(url)) {
    event.respondWith(fetch(event.request, { cache: 'no-store' }));
  }
});
